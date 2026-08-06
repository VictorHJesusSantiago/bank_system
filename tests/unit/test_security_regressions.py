"""Regressões das falhas de controle de acesso encontradas na auditoria.

Cada teste falha na versão anterior do código e documenta a invariante que a
correção passou a garantir.
"""

from datetime import UTC, datetime, timedelta

import pytest

from bank_advanced import AdvancedBanking
from bank_core import (
    AuthenticationError,
    AuthorizationError,
    BankDatabase,
    BankingCore,
    LedgerService,
    SecurityService,
)
from bank_openfinance import OpenFinanceService

PASSWORD = "Senha#Forte2024!"


@pytest.fixture
def core(tmp_path):
    bank = BankingCore(tmp_path / "core.db")
    bank.ledger.create_account("2001", "vitima", initial_balance="5000")
    bank.ledger.create_account("2002", "atacante", initial_balance="10")
    return bank


def test_self_granted_account_access_is_rejected(core):
    """Auto-concessão dava a qualquer usuário acesso a qualquer conta."""
    attacker = core.security.create_user("atacante", PASSWORD)
    with pytest.raises(AuthorizationError):
        core.security.grant_account_access(attacker, attacker, "2001", "OWNER", ["TRANSACT"])
    with pytest.raises(AuthorizationError):
        core.security.require_account_access(attacker, "2001", "TRANSACT")


def test_manager_can_still_grant_account_access(core):
    manager = core.security.create_user("gerente", PASSWORD, roles=("MANAGER",))
    client = core.security.create_user("cliente", PASSWORD)
    core.security.grant_account_access(manager, client, "2001", "PROXY", ["TRANSACT"])
    core.security.require_account_access(client, "2001", "TRANSACT")


def test_access_not_yet_valid_is_refused(core):
    """`valid_from` era gravado mas nunca conferido."""
    manager = core.security.create_user("gerente2", PASSWORD, roles=("MANAGER",))
    client = core.security.create_user("cliente2", PASSWORD)
    core.security.grant_account_access(manager, client, "2001", "PROXY", ["TRANSACT"])
    future = (datetime.now(UTC) + timedelta(days=1)).isoformat()
    with core.database.transaction() as con:
        con.execute("UPDATE account_access SET valid_from=? WHERE user_id=?", (future, client))
    with pytest.raises(AuthorizationError):
        core.security.require_account_access(client, "2001", "TRANSACT")


def test_totp_failure_counts_toward_lockout(core):
    """TOTP sem contador transformava o 2FA em 10^6 tentativas gratuitas."""
    user = core.security.create_user("comtotp", PASSWORD)
    core.security.enable_totp(user)
    for _ in range(3):
        with pytest.raises(AuthenticationError):
            core.security.authenticate("comtotp", PASSWORD, totp_code="000000")
    with core.database.connect() as con:
        row = con.execute(
            "SELECT failed_attempts,locked_until FROM users WHERE user_id=?", (user,)
        ).fetchone()
    assert row["failed_attempts"] >= 3 and row["locked_until"]


def test_refresh_token_cannot_outlive_absolute_session_cap(core):
    """O refresh renovava a si mesmo indefinidamente."""
    core.security.create_user("renova", PASSWORD)
    tokens = core.security.authenticate("renova", PASSWORD)
    old = (datetime.now(UTC) - timedelta(hours=SecurityService.ABSOLUTE_SESSION_HOURS + 1)).isoformat()
    with core.database.transaction() as con:
        con.execute("UPDATE sessions SET created_at=? WHERE session_id=?", (old, tokens["session_id"]))
    with pytest.raises(AuthenticationError):
        core.security.refresh_session(tokens["refresh_token"])


def test_open_finance_payment_cannot_debit_a_foreign_account(tmp_path):
    """Um consentimento autorizava débito em qualquer conta do banco."""
    db = BankDatabase(tmp_path / "of.db")
    ledger = LedgerService(db)
    ledger.create_account("3001", "vitima", initial_balance="5000")
    ledger.create_account("3002", "atacante", initial_balance="0")
    service = OpenFinanceService(db, ledger)
    client = service.create_client("agregador", {"PAYMENTS_INITIATE"})
    consent = service.create_consent("atacante", client["client_id"], {"PAYMENTS_INITIATE"})
    service.authenticate_consent(consent, "atacante")
    service.confirm_consent(consent, "atacante")
    with pytest.raises(AuthorizationError):
        service.initiate_payment(consent, client["client_id"], "k1", "3001", "3002", "500")
    assert ledger.account("3001")["ledger_balance_cents"] == 500000


def test_account_block_is_idempotent(tmp_path):
    """Repetir o bloqueio congelava o dobro do saldo."""
    db = BankDatabase(tmp_path / "blk.db")
    ledger = LedgerService(db)
    ledger.create_account("4001", "titular", initial_balance="1000")
    advanced = AdvancedBanking(db, ledger)
    advanced.accounts.configure("4001", "CHECKING", [("c1", "OWNER")])
    advanced.accounts.block("4001", "Ordem judicial", legal="300")
    advanced.accounts.block("4001", "Ordem judicial", legal="300")
    assert ledger.account("4001")["blocked_balance_cents"] == 30000
