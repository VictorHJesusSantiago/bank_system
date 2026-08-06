"""Backlog MEDIUM/LOW da auditoria: correções de robustez e correção fina."""

from datetime import UTC, datetime, timedelta

import pytest

from bank_advanced import AdvancedBanking
from bank_core import (
    AuthenticationError,
    BankDatabase,
    BankError,
    BankingCore,
    LedgerService,
    ModuleIntegrationService,
    SecurityService,
)
from bank_observability import TRACER, correlation
from bank_openfinance import OpenFinanceService
from bank_pix import PixService

PASSWORD = "Senha#Forte2024!"


@pytest.fixture
def core(tmp_path):
    bank = BankingCore(tmp_path / "backlog.db")
    bank.ledger.create_account("8001", "dono", initial_balance="1000")
    return bank




def test_totp_code_cannot_be_replayed(core):
    """A janela de ±1 passo mantinha um código observado válido por 90 s."""
    user = core.security.create_user("comtotp", PASSWORD)
    secret = core.security.enable_totp(user)["secret"]
    code = SecurityService.totp(secret)
    assert core.security.authenticate("comtotp", PASSWORD, totp_code=code)
    with pytest.raises(AuthenticationError):
        core.security.authenticate("comtotp", PASSWORD, totp_code=code)


def test_recovery_code_works_as_second_factor(core):
    """Os códigos eram emitidos mas nenhum fluxo os aceitava."""
    user = core.security.create_user("recupera", PASSWORD)
    codes = core.security.enable_totp(user)["recovery_codes"]
    assert core.security.authenticate("recupera", PASSWORD, totp_code=codes[0])
    with pytest.raises(AuthenticationError):
        core.security.authenticate("recupera", PASSWORD, totp_code=codes[0])
    assert core.security.authenticate("recupera", PASSWORD, totp_code=codes[1])


def test_password_reset_requests_are_rate_limited(core):
    core.security.create_user("alvo", PASSWORD)
    for _ in range(SecurityService.RESET_REQUESTS_PER_HOUR):
        core.security.request_password_reset("alvo", "alvo@example.com")
    with pytest.raises(AuthenticationError) as exc:
        core.security.request_password_reset("alvo", "alvo@example.com")
    assert exc.value.code == "RESET_RATE_LIMITED"


def test_unknown_user_reset_stays_silent_and_unthrottled(core):
    """Resposta uniforme: o rate limit não pode virar oráculo de existência."""
    for _ in range(SecurityService.RESET_REQUESTS_PER_HOUR + 2):
        assert core.security.request_password_reset("inexistente", "x@example.com") is None


def test_approve_returns_the_state_it_just_wrote(core):
    solicitante = core.security.create_user("sol", PASSWORD, roles=("MANAGER",))
    aprovador = core.security.create_user("apr", PASSWORD, roles=("MANAGER",))
    approval = core.security.request_approval("LIMIT_INCREASE", "8001", {"limite": "5000"}, solicitante)
    result = core.security.approve(approval, aprovador)
    assert result["state"] == "APPROVED"
    assert result["approved_by"] == aprovador
    assert result["payload"] == {"limite": "5000"}




def test_monthly_recurrence_returns_to_the_contracted_day():
    """Cair em fevereiro não pode mover o vencimento em definitivo."""
    moment = "2026-01-31T10:00:00+00:00"
    days = []
    for _ in range(4):
        moment = ModuleIntegrationService._next_run(moment, "MONTHLY", 31)
        days.append(moment[:10])
    assert days == ["2026-02-28", "2026-03-31", "2026-04-30", "2026-05-31"]


def test_failed_job_backs_off_instead_of_retrying_immediately(tmp_path):
    db = BankDatabase(tmp_path / "jobs.db")
    ledger = LedgerService(db)
    modules = ModuleIntegrationService(db, ledger)
    past = (datetime.now(UTC) - timedelta(minutes=1)).isoformat()
    job = modules.schedule("CASHBACK", {"module": "M", "account_number": "inexistente", "amount": "10"}, past)
    assert modules.run_due() == {"processed": 0, "failed": 1}
    with db.connect() as con:
        row = con.execute("SELECT attempts,next_run_at FROM scheduled_jobs WHERE job_id=?", (job,)).fetchone()
    assert row["attempts"] == 1
    assert datetime.fromisoformat(row["next_run_at"]) > datetime.now(UTC)
    assert modules.run_due() == {"processed": 0, "failed": 0}
    db.close_pool()


def test_retry_delay_grows_and_is_capped():
    delays = [ModuleIntegrationService.retry_at(n) for n in (1, 2, 10)]
    moments = [datetime.fromisoformat(d) for d in delays]
    assert moments[0] < moments[1] < moments[2]
    assert moments[2] <= datetime.now(UTC) + timedelta(hours=1, seconds=5)




def test_statement_is_paginated(tmp_path):
    db = BankDatabase(tmp_path / "ext.db")
    ledger = LedgerService(db)
    ledger.create_account("9101", "dono", initial_balance="1000")
    ledger.create_account("9102", "outro", initial_balance="0")
    advanced = AdvancedBanking(db, ledger)
    for index in range(6):
        ledger.transfer("9101", "9102", "1", f"t{index}")
    today = datetime.now(UTC).date().isoformat()
    page = advanced.accounts.statement("9101", today, today, limit=2)
    assert len(page) == 2
    assert len(advanced.accounts.statement("9101", today, today, limit=2, offset=2)) == 2
    db.close_pool()


def test_open_finance_share_limit_is_capped(tmp_path):
    db = BankDatabase(tmp_path / "share.db")
    ledger = LedgerService(db)
    ledger.create_account("9201", "user-1", initial_balance="10")
    service = OpenFinanceService(db, ledger)
    client = service.create_client("agg", {"TRANSACTIONS_READ"})
    consent = service.create_consent("user-1", client["client_id"], {"TRANSACTIONS_READ"})
    service.authenticate_consent(consent, "user-1")
    service.confirm_consent(consent, "user-1")
    result = service.share(consent, client["client_id"], "TRANSACTIONS_READ", "corr-1", {"limit": 10**9})
    assert len(result["data"]) <= OpenFinanceService.MAX_SHARE_LIMIT
    db.close_pool()




def test_webhook_delivery_reports_sandbox_mode(tmp_path):
    db = BankDatabase(tmp_path / "wh.db")
    ledger = LedgerService(db)
    pix = PixService(db, ledger)
    pix.queue_webhook("PIX_CONFIRMED", {"x": 1})
    assert pix.deliver_webhooks() == {"sent": 1, "failed": 0, "mode": "SANDBOX"}
    db.close_pool()


def test_webhook_transport_failure_is_retried_then_parked(tmp_path):
    db = BankDatabase(tmp_path / "wh2.db")
    ledger = LedgerService(db)
    pix = PixService(db, ledger)
    identifier = pix.queue_webhook("PIX_CONFIRMED", {"x": 1})

    def failing(url, payload, signature):
        raise ConnectionError("destino fora do ar")

    for _ in range(PixService.MAX_WEBHOOK_ATTEMPTS):
        pix.deliver_webhooks(transport=failing)
    with db.connect() as con:
        state = con.execute("SELECT state FROM pix_webhooks WHERE webhook_id=?", (identifier,)).fetchone()[0]
    assert state == "FAILED"
    db.close_pool()


def test_webhook_transport_success_marks_sent(tmp_path):
    db = BankDatabase(tmp_path / "wh3.db")
    ledger = LedgerService(db)
    pix = PixService(db, ledger)
    pix.queue_webhook("PIX_CONFIRMED", {"x": 1})
    entregues = []
    result = pix.deliver_webhooks(transport=lambda url, payload, signature: entregues.append(url))
    assert result == {"sent": 1, "failed": 0, "mode": "TRANSPORT"} and entregues
    db.close_pool()


def test_unknown_engine_state_is_a_domain_error(tmp_path):
    db = BankDatabase(tmp_path / "eng.db")
    ledger = LedgerService(db)
    advanced = AdvancedBanking(db, ledger)
    transaction = advanced.transactions.create("TEST", "idem-1", "Teste", "10")
    with db.transaction() as con:
        con.execute(
            "UPDATE transaction_details SET engine_state='ESTADO_INVENTADO' WHERE transaction_id=?",
            (transaction,),
        )
    with pytest.raises(BankError) as exc:
        advanced.transactions.transition(transaction, "AUTHORIZED")
    assert exc.value.code == "UNKNOWN_STATE"
    db.close_pool()




def test_otlp_export_matches_the_specification():
    TRACER.reset()
    with correlation("abc"):
        with TRACER.start("op", **{"http.status_code": 200, "ok": True, "ratio": 0.5}):
            pass
    payload = TRACER.export_otlp("banco-teste")
    resource = payload["resourceSpans"][0]
    assert {"key": "service.name", "value": {"stringValue": "banco-teste"}} in resource["resource"][
        "attributes"
    ]
    span = resource["scopeSpans"][0]["spans"][0]
    assert len(span["traceId"]) == 32 and len(span["spanId"]) == 16
    assert int(span["endTimeUnixNano"]) >= int(span["startTimeUnixNano"])
    assert span["status"]["code"] == 1
    tipos = {a["key"]: next(iter(a["value"])) for a in span["attributes"]}
    assert tipos == {"http.status_code": "intValue", "ok": "boolValue", "ratio": "doubleValue"}


def test_otlp_marks_failed_spans_as_error():
    TRACER.reset()
    with pytest.raises(RuntimeError):
        with TRACER.start("falha"):
            raise RuntimeError("x")
    span = TRACER.export_otlp()["resourceSpans"][0]["scopeSpans"][0]["spans"][0]
    assert span["status"]["code"] == 2
