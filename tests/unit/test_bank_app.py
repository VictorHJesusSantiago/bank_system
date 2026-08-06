"""Testes do composition root: os padrões seguros precisam vir ligados."""

import base64
import secrets

import pytest

from bank_advanced import (
    EnvKeyProvider,
    ExplicitKeyProvider,
    LocalFileKeyProvider,
    VaultService,
)
from bank_app import BankApplication
from bank_core import AccountingError, AuthorizationError, BankError, Money
from bank_observability import JsonFormatter, Metrics, correlation, get_logger

PASSWORD = "Senha#Forte2024!"


@pytest.fixture
def app(tmp_path):
    application = BankApplication(tmp_path / "app.db")
    owner = application.security.create_user("titular", PASSWORD)
    manager = application.security.create_user("gerente", PASSWORD, roles=("MANAGER",))
    application.ledger.create_account("9001", owner, initial_balance="1000")
    application.ledger.create_account("9002", "terceiro", initial_balance="0")
    application.security.grant_account_access(manager, owner, "9001", "OWNER", ["TRANSACT"])
    return application, owner, manager


def test_pix_debit_requires_account_ownership(app):
    application, owner, manager = app
    key = application.pix.register_key("9002", "EMAIL", "b@example.com", "Beneficiario")
    receipt = application.pix.transfer("9001", key["key"], "50", "p1", confirmed=True, actor_id=owner)
    assert receipt["amount"] == "50.00"
    with pytest.raises(AuthorizationError):
        application.pix.transfer("9001", key["key"], "10", "p2", confirmed=True, actor_id=manager)
    with pytest.raises(AuthorizationError):
        application.pix.transfer("9001", key["key"], "10", "p3", confirmed=True)


def test_pix_key_is_encrypted_at_rest(app):
    application, _, _ = app
    key = application.pix.register_key("9002", "CPF", "39053344705", "Titular")
    with application.database.connect() as con:
        stored = con.execute("SELECT key_value FROM pix_keys").fetchone()[0]
    assert stored.startswith("vault:") and "39053344705" not in stored
    assert application.pix.resolve_key(key["key"])["account_number"] == "9002"


def test_open_finance_private_key_is_encrypted_at_rest(app):
    application, _, _ = app
    certificate = application.open_finance.issue_certificate()
    with application.database.connect() as con:
        stored = con.execute("SELECT private_key FROM of_certificates").fetchone()[0]
    assert stored.startswith("vault:") and "PRIVATE KEY" not in stored
    signature = application.open_finance.sign(certificate["certificate_id"], b"payload")
    assert application.open_finance.verify(certificate["certificate_id"], b"payload", signature)


def test_health_reports_ledger_and_audit_integrity(app):
    application, _, _ = app
    health = application.health()
    assert health["status"] == "UP"
    assert health["reconciliation"]["ok"] and health["audit_chain_valid"]


def test_vault_refuses_to_invent_a_master_key(tmp_path, monkeypatch):
    """ADR-001: sem custódia declarada o cofre falha em vez de gerar chave em disco."""
    monkeypatch.delenv("BANK_MASTER_KEY", raising=False)
    monkeypatch.delenv(LocalFileKeyProvider.OPT_IN, raising=False)
    from bank_core import BankDatabase

    db = BankDatabase(tmp_path / "novault.db")
    with pytest.raises(BankError) as exc:
        VaultService(db)
    assert exc.value.code == "MASTER_KEY_UNAVAILABLE"
    assert not (tmp_path / "novault.master.key").exists()


def test_key_providers_round_trip(tmp_path, monkeypatch):
    from bank_core import BankDatabase

    key = secrets.token_bytes(32)
    monkeypatch.setenv(EnvKeyProvider.VARIABLE, base64.urlsafe_b64encode(key).decode())
    db = BankDatabase(tmp_path / "kp.db")
    vault = VaultService(db, key_provider=EnvKeyProvider())
    object_id = vault.encrypt("TEST", "segredo")
    assert vault.decrypt(object_id) == b"segredo"
    assert VaultService(db, key_provider=ExplicitKeyProvider(key)).decrypt(object_id) == b"segredo"


def test_money_makes_the_unit_explicit():
    assert Money.parse("100").cents == 10_000
    assert Money.from_cents(100).cents == 100
    assert str(Money.parse("10.50") + Money.parse("0.50")) == "11.00"
    with pytest.raises(AccountingError) as exc:
        Money.parse(100)
    assert exc.value.code == "AMBIGUOUS_AMOUNT"


def test_structured_log_redacts_secrets(caplog):
    logger = get_logger("bank.test")
    record = logger.makeRecord(
        "bank.test",
        20,
        __file__,
        1,
        "login",
        None,
        None,
        extra={"password": "muito-secreta", "actor_id": "u1"},
    )
    rendered = JsonFormatter().format(record)
    assert "muito-secreta" not in rendered
    assert '"password": "***"' in rendered and '"actor_id": "u1"' in rendered


def test_metrics_report_percentiles_not_averages():
    metrics = Metrics()
    for value in [1, 1, 1, 1, 1000]:
        metrics.observe("latency_ms", value)
    percentiles = metrics.percentiles("latency_ms")
    assert percentiles["p50"] == 1 and percentiles["p99"] == 1000
    metrics.increment("requests_total", status="200")
    assert 'requests_total{status="200"} 1' in metrics.render_prometheus()


def test_correlation_id_propagates_into_logs():
    with correlation("abc-123") as identifier:
        assert identifier == "abc-123"
        logger = get_logger("bank.test")
        record = logger.makeRecord("bank.test", 20, __file__, 1, "evento", None, None)
        assert '"correlation_id": "abc-123"' in JsonFormatter().format(record)
