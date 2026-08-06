from __future__ import annotations

import sqlite3
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest

from bank_core import (
    AccountingError,
    AuthenticationError,
    AuthorizationError,
    BankingCore,
    Posting,
)


@pytest.fixture
def core(tmp_path):
    return BankingCore(tmp_path / "core.db")


@pytest.fixture
def users(core):
    admin = core.security.create_user("admin", "Cofre#Principal2026", roles=["ADMIN"])
    manager = core.security.create_user("gerente", "Senha#Gerencial2026", roles=["MANAGER"])
    client = core.security.create_user("cliente", "Cofre#PessoaFisica2026", cpf_cnpj="52998224725")
    return admin, manager, client


def test_schema_integrity_and_chart(core):
    assert core.database.integrity_check()["ok"]
    with core.database.connect() as con:
        assert con.execute("SELECT COUNT(*) FROM chart_accounts").fetchone()[0] >= 10
        assert con.execute("SELECT MAX(version) FROM schema_migrations").fetchone()[0] == 1


def test_opening_balance_and_reconciliation(core, users):
    _, _, client = users
    core.ledger.create_account("1001", client, initial_balance="123.45")
    account = core.ledger.account("1001")
    assert account["ledger_balance"] == Decimal("123.45")
    assert account["available_balance"] == Decimal("123.45")
    assert core.ledger.reconcile()["ok"]


def test_double_entry_rejects_unbalanced(core):
    with pytest.raises(AccountingError, match="diferentes"):
        core.ledger.post(
            "BROKEN",
            "broken:1",
            "inválida",
            [
                Posting("CASH", debit_cents=100),
                Posting("FEE_REVENUE", credit_cents=99),
            ],
        )


def test_transfer_is_atomic_balanced_and_idempotent(core, users):
    _, _, client = users
    core.ledger.create_account("1001", client, initial_balance="100.00")
    core.ledger.create_account("1002", client, initial_balance="10.00")
    first = core.ledger.transfer("1001", "1002", "25.50", "transfer:1", fee="1.00")
    second = core.ledger.transfer("1001", "1002", "25.50", "transfer:1", fee="1.00")
    assert first == second
    assert core.ledger.account("1001")["ledger_balance"] == Decimal("73.50")
    assert core.ledger.account("1002")["ledger_balance"] == Decimal("35.50")
    assert core.ledger.reconcile()["ok"]


def test_insufficient_funds_rolls_back_everything(core, users):
    _, _, client = users
    core.ledger.create_account("1001", client, initial_balance="10")
    core.ledger.create_account("1002", client)
    with pytest.raises(AccountingError, match="insuficiente"):
        core.ledger.transfer("1001", "1002", "11", "transfer:fail")
    assert core.ledger.account("1001")["ledger_balance"] == Decimal("10.00")
    assert core.ledger.account("1002")["ledger_balance"] == Decimal("0.00")
    with core.database.connect() as con:
        assert (
            con.execute(
                "SELECT COUNT(*) FROM ledger_transactions WHERE idempotency_key='transfer:fail'"
            ).fetchone()[0]
            == 0
        )


def test_full_and_partial_reversal(core, users):
    _, _, client = users
    core.ledger.create_account("1001", client, initial_balance="100")
    core.ledger.create_account("1002", client)
    transaction = core.ledger.transfer("1001", "1002", "40", "transfer:reverse")
    core.ledger.reverse(transaction, "reverse:partial", "15")
    assert core.ledger.account("1001")["ledger_balance"] == Decimal("75.00")
    assert core.ledger.account("1002")["ledger_balance"] == Decimal("25.00")
    core.ledger.reverse(transaction, "reverse:rest")
    assert core.ledger.account("1001")["ledger_balance"] == Decimal("100.00")
    assert core.ledger.account("1002")["ledger_balance"] == Decimal("0.00")
    with pytest.raises(AccountingError):
        core.ledger.reverse(transaction, "reverse:excess", "1")


def test_pending_settlement_updates_projected_then_ledger(core, users):
    _, _, client = users
    core.ledger.create_account("1001", client, initial_balance="100")
    transaction = core.ledger.post(
        "FUTURE_PAYMENT",
        "future:1",
        "Compensação futura",
        [
            Posting("CUSTOMER_DEPOSITS", debit_cents=2500, customer_account="1001"),
            Posting("SETTLEMENT", credit_cents=2500),
        ],
        balance_deltas={"1001": -2500},
        settlement_at=(datetime.now(UTC) + timedelta(days=1)).isoformat(),
    )
    account = core.ledger.account("1001")
    assert account["ledger_balance"] == Decimal("100.00")
    assert account["projected_balance"] == Decimal("75.00")
    core.ledger.settle_pending(transaction)
    account = core.ledger.account("1001")
    assert account["ledger_balance"] == Decimal("75.00")
    assert account["projected_balance"] == Decimal("75.00")


def test_holds_release(core, users):
    _, _, client = users
    core.ledger.create_account("1001", client, initial_balance="100")
    hold = core.ledger.create_hold("1001", "30", "compra")
    assert core.ledger.account("1001")["blocked_balance"] == Decimal("30.00")
    assert core.ledger.account("1001")["available_balance"] == Decimal("70.00")
    core.ledger.release_hold(hold)
    assert core.ledger.account("1001")["blocked_balance"] == Decimal("0.00")


def test_hold_capture_is_atomic_and_idempotent(core, users):
    _, _, client = users
    core.ledger.create_account("1001", client, initial_balance="100")
    hold = core.ledger.create_hold("1001", "30", "compra")
    first = core.ledger.capture_hold(hold, "capture:1", "20")
    second = core.ledger.capture_hold(hold, "capture:1", "20")
    assert first == second
    account = core.ledger.account("1001")
    assert account["ledger_balance"] == Decimal("80.00")
    assert account["blocked_balance"] == Decimal("10.00")
    core.ledger.capture_hold(hold, "capture:2")
    account = core.ledger.account("1001")
    assert account["ledger_balance"] == Decimal("70.00")
    assert account["blocked_balance"] == Decimal("0.00")
    assert core.ledger.reconcile()["ok"]


def test_satellite_debit_credit_and_notification(core, users):
    _, _, client = users
    core.ledger.create_account("1001", client, initial_balance="100")
    core.modules.settle("BANKDOA", "DONATION", "1001", "20", "doa:1")
    core.modules.settle("BANKCASHBACK", "CASHBACK", "1001", "5", "cash:1")
    assert core.ledger.account("1001")["ledger_balance"] == Decimal("85.00")
    with core.database.connect() as con:
        assert con.execute("SELECT COUNT(*) FROM module_events").fetchone()[0] == 2
        assert con.execute("SELECT COUNT(*) FROM outbox").fetchone()[0] == 2


def test_card_purchase_generates_cashback_from_real_purchase(core, users):
    _, _, client = users
    core.ledger.create_account("1001", client, initial_balance="100")
    result = core.modules.settle_card_purchase("1001", "20", "5", "card:1", merchant="Mercado")
    assert result["cashback_cents"] == 100
    assert core.ledger.account("1001")["ledger_balance"] == Decimal("81.00")
    assert core.ledger.reconcile()["ok"]


def test_credit_score_uses_ledger_data(core, users):
    _, _, client = users
    core.ledger.create_account("1001", client, initial_balance="100")
    core.modules.settle("BANKDOA", "DONATION", "1001", "10", "doa:score")
    result = core.modules.calculate_credit_score("1001")
    assert 0 <= result["score"] <= 1000
    assert result["factors"]["operations"] > 0


def test_recurring_satellite_job(core, users):
    _, _, client = users
    core.ledger.create_account("1001", client, initial_balance="100")
    run_at = (datetime.now(UTC) - timedelta(seconds=1)).isoformat()
    core.modules.schedule(
        "RECURRING_DONATION",
        {
            "module": "BANKDOA",
            "account_number": "1001",
            "amount": "10",
            "details": {"institution": "ONG"},
        },
        run_at,
        recurrence="MONTHLY",
    )
    result = core.modules.run_due()
    assert result == {"processed": 1, "failed": 0}
    assert core.ledger.account("1001")["ledger_balance"] == Decimal("90.00")


def test_argon2_hash_and_login_session(core, users):
    _, _, client = users
    with core.database.connect() as con:
        stored = con.execute("SELECT password_hash FROM users WHERE user_id=?", (client,)).fetchone()[0]
    assert stored.startswith("$argon2id$")
    assert "Cofre#PessoaFisica2026" not in stored
    login = core.security.authenticate("cliente", "Cofre#PessoaFisica2026")
    session = core.security.require_session(login["token"])
    assert session["user_id"] == client
    refreshed = core.security.refresh_session(login["refresh_token"])
    assert refreshed["token"] != login["token"]


def test_transparent_legacy_password_migration(core):
    user_id = core.security.migrate_legacy_credential(
        "legado", "Cofre#SistemaAntigo2026", "Cofre#SistemaAntigo2026"
    )
    with core.database.connect() as con:
        stored = con.execute("SELECT password_hash FROM users WHERE user_id=?", (user_id,)).fetchone()[0]
    assert stored.startswith("$argon2id$")
    assert "SistemaAntigo" not in stored
    with pytest.raises(AuthenticationError):
        core.security.migrate_legacy_credential("invalido", "Cofre#Original2026", "Cofre#Diferente2026")


def test_persistent_progressive_lockout(core, users):
    for _ in range(3):
        with pytest.raises(AuthenticationError):
            core.security.authenticate("cliente", "Senha#Errada2026")
    with pytest.raises(AuthenticationError) as caught:
        core.security.authenticate("cliente", "Cofre#PessoaFisica2026")
    assert caught.value.code == "USER_LOCKED"


def test_password_policy_history_and_session_revocation(core, users):
    _, _, client = users
    login = core.security.authenticate("cliente", "Cofre#PessoaFisica2026")
    with pytest.raises(AuthenticationError):
        core.security.change_password(client, "Cofre#PessoaFisica2026", "fraca")
    core.security.change_password(client, "Cofre#PessoaFisica2026", "Outra#ChavePessoa2027")
    with pytest.raises(AuthenticationError):
        core.security.require_session(login["token"])
    with pytest.raises(AuthenticationError) as caught:
        core.security.change_password(client, "Outra#ChavePessoa2027", "Cofre#PessoaFisica2026")
    assert caught.value.code == "PASSWORD_REUSED"


def test_totp_and_recovery_codes(core, users):
    _, _, client = users
    setup = core.security.enable_totp(client)
    code = core.security.totp(setup["secret"])
    login = core.security.authenticate("cliente", "Cofre#PessoaFisica2026", totp_code=code)
    assert login["token"]
    recovery = setup["recovery_codes"][0]
    assert core.security.use_recovery_code(client, recovery)
    assert not core.security.use_recovery_code(client, recovery)


def test_reset_token_and_outbox(core, users):
    _, _, client = users
    token = core.security.request_password_reset("cliente", "cliente@example.com", "EMAIL")
    assert token
    core.security.complete_password_reset(token, "Nova#ChavePessoa2028")
    core.security.authenticate("cliente", "Nova#ChavePessoa2028")
    with pytest.raises(AuthenticationError):
        core.security.complete_password_reset(token, "Terceira#Senha2029")
    with core.database.connect() as con:
        assert con.execute("SELECT COUNT(*) FROM outbox WHERE template='PASSWORD_RESET'").fetchone()[0] == 1
    result = core.outbox.deliver_pending()
    assert result == {"delivered": 1, "failed": 0}
    assert list(core.outbox.directory.glob("*.json"))


def test_rbac_account_ownership_and_representative(core, users):
    admin, _, client = users
    operator = core.security.create_user("operador", "Cofre#EmpresaSegura2026", roles=["PJ_OPERATOR"])
    core.ledger.create_account("PJ01", client, kind="PJ")
    core.security.grant_account_access(admin, operator, "PJ01", "REPRESENTATIVE", ["READ", "TRANSACT"])
    core.security.require_account_access(operator, "PJ01", "TRANSACT")
    with pytest.raises(AuthorizationError):
        core.security.require_permission(operator, "ROLE_MANAGE")


def test_four_eyes_approval(core, users):
    admin, manager, _ = users
    approval = core.security.request_approval("ADMIN_ADJUSTMENT", "1001", {"amount": "10"}, admin)
    with pytest.raises(AuthorizationError) as caught:
        core.security.approve(approval, admin)
    assert caught.value.code == "FOUR_EYES"
    approved = core.security.approve(approval, manager)
    assert approved["payload"]["amount"] == "10"


def test_admin_adjustment_requires_and_consumes_approval(core, users):
    admin, manager, client = users
    core.ledger.create_account("1001", client)
    approval = core.security.request_approval(
        "ADMIN_ADJUSTMENT",
        "1001",
        {"amount": "10", "direction": "CREDIT"},
        admin,
    )
    core.security.approve(approval, manager)
    core.execute_admin_adjustment(approval, admin, "1001", "10", "CREDIT", "Correção conciliada")
    assert core.ledger.account("1001")["ledger_balance"] == Decimal("10.00")
    with pytest.raises(AuthorizationError):
        core.execute_admin_adjustment(approval, admin, "1001", "10", "CREDIT", "Duplicada")


def test_audit_chain_detects_tampering(core, users):
    assert core.security.verify_audit_chain()
    with core.database.transaction() as con:
        con.execute(
            "UPDATE audit_events SET details='adulterado' WHERE sequence=(SELECT MIN(sequence) FROM audit_events)"
        )
    assert not core.security.verify_audit_chain()


def test_daily_close_and_backup(core, users, tmp_path):
    _, _, client = users
    core.ledger.create_account("1001", client, initial_balance="10")
    today = datetime.now(UTC).date().isoformat()
    core.ledger.close_period(today, "DAILY", client)
    backup = core.database.backup(tmp_path / "backup.db")
    assert backup.exists()
    with sqlite3.connect(backup) as con:
        assert con.execute("PRAGMA integrity_check").fetchone()[0] == "ok"


def test_database_repair(core):
    assert core.database.repair()["ok"]
