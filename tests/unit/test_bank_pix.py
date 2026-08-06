from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest

from bank_core import (
    AuthorizationError,
    BankDatabase,
    BankError,
    LedgerService,
    ModuleIntegrationService,
    SecurityService,
)
from bank_pix import PixService


@pytest.fixture
def pix(tmp_path):
    db = BankDatabase(tmp_path / "pix.db")
    ledger = LedgerService(db)
    ledger.create_account("1001", "a", initial_balance="1000")
    ledger.create_account("1002", "b", initial_balance="100")
    service = PixService(db, ledger, ModuleIntegrationService(db, ledger))
    key = service.register_key("1002", "EMAIL", "destino@example.com", "Destino")
    return service, ledger, db, key


@pytest.fixture
def pix_with_security(tmp_path):
    """PixService com RBAC ativo e um gerente apto a aprovar chaves."""
    db = BankDatabase(tmp_path / "pix_sec.db")
    ledger = LedgerService(db)
    ledger.create_account("1001", "a", initial_balance="1000")
    ledger.create_account("1002", "b", initial_balance="100")
    security = SecurityService(db)
    service = PixService(db, ledger, ModuleIntegrationService(db, ledger), security=security)
    manager = security.create_user("gerente-pix", "Senha#Forte2024!", roles=("MANAGER",))
    return service, manager


def test_key_full_lifecycle_and_resolution(pix):
    service, _, _, key = pix
    evp = service.register_key("1001", "EVP", None, "Origem")
    assert len(evp["key"]) == 36
    assert len(service.list_keys("1001")) == 1
    replacement = service.replace_key(evp["key_id"], "1001", "PHONE", "11987654321", "Origem")
    assert service.resolve_key(replacement["key"])["owner_name"] == "Origem"
    service.delete_key(replacement["key_id"], "1001")
    with pytest.raises(BankError):
        service.resolve_key(replacement["key"])


def test_portability_and_claim(pix_with_security):
    service, manager = pix_with_security
    key = service.register_key("1002", "EMAIL", "destino@example.com", "Destino")
    assert service.portability(key["key"], "1001") == "REQUESTED"
    assert service.portability(key["key"], "1001", approve=True, approved_by=manager) == "APPROVED"
    assert service.resolve_key(key["key"])["account_number"] == "1001"
    assert service.claim_ownership(key["key"], "1002", "APPROVED", approved_by=manager) == "APPROVED"


def test_key_reassignment_requires_authority(pix, pix_with_security):
    """Aprovar portabilidade/reivindicação sem autoridade sequestraria a chave."""
    service, _, _, key = pix
    with pytest.raises(AuthorizationError):
        service.portability(key["key"], "1001", approve=True)
    with pytest.raises(AuthorizationError):
        service.claim_ownership(key["key"], "1001", "APPROVED")
    assert service.resolve_key(key["key"])["account_number"] == "1002"

    secured, _ = pix_with_security
    client = secured.security.create_user("cliente-pix", "Senha#Forte2024!")
    other = secured.register_key("1002", "EMAIL", "outro@example.com", "Destino")
    with pytest.raises(AuthorizationError):
        secured.claim_ownership(other["key"], "1001", "APPROVED", approved_by=client)


def test_confirmation_transfer_receipt_and_idempotency(pix):
    service, ledger, _, key = pix
    preview = service.transfer("1001", key["key"], "50", "pix:1")
    assert preview["confirmation_required"] and preview["institution"]
    receipt = service.transfer("1001", key["key"], "50", "pix:1", confirmed=True)
    again = service.transfer("1001", key["key"], "50", "pix:1", confirmed=True)
    assert receipt["transaction_id"] == again["transaction_id"]
    assert receipt["e2e_id"].startswith("E")
    assert ledger.account("1001")["ledger_balance"] == Decimal("950.00")


def test_limits_and_trusted_contact(pix):
    service, _, _, key = pix
    service.configure_limits("1001", "100", "100", 0, 23, "20")
    service.trust_contact("1001", key["key"], "Contato", "30")
    with pytest.raises(AuthorizationError):
        service.transfer("1001", key["key"], "31", "pix:limit", confirmed=True)


def test_emv_static_dynamic_open_fixed_and_crc(pix):
    service, _, _, key = pix
    static = service.emv_payload(key["key"], "Destino", "***", "Compra")
    fixed = service.emv_payload(key["key"], "Destino", "TX123", "Compra", "12.34", True)
    assert service.validate_emv(static)["pix_key"] == key["key"]
    assert service.validate_emv(fixed)["txid"] == "TX123"
    with pytest.raises(BankError):
        service.validate_emv(fixed[:-1] + "0")


def test_charge_due_rules_payment_webhook_and_reconciliation(pix):
    service, ledger, db, key = pix
    due = (datetime.now(UTC) - timedelta(days=1)).isoformat()
    charge = service.create_charge(
        key["key_id"], "Cobrança", "100", due, interest="1", mult="2", discount="0"
    )
    receipt = service.pay_charge(charge["txid"], "1001", "100", "Pagador", "52998224725")
    assert receipt["amount"] == "103.00"
    assert ledger.account("1002")["ledger_balance"] == Decimal("203.00")
    assert service.deliver_webhooks()["sent"] >= 1
    with db.connect() as con:
        assert (
            con.execute("SELECT state FROM pix_reconciliation WHERE txid=?", (charge["txid"],)).fetchone()[0]
            == "DIVERGENT"
        )


def test_total_partial_refund_request_history_and_dispute(pix):
    service, ledger, _, key = pix
    receipt = service.transfer("1001", key["key"], "100", "pix:refund", confirmed=True)
    request = service.request_refund(receipt["pix_id"], "10", "solicitação", "user")
    partial = service.refund(receipt["pix_id"], "30", "parcial", "receiver")
    assert request and partial
    assert len(service.refund_history(receipt["pix_id"])) == 2
    assert service.dispute(receipt["pix_id"], "fraude", {"proof": "x"})
    assert service.caution_block(receipt["pix_id"], "20", "análise")
    service.refund(receipt["pix_id"], None, "restante", "receiver")
    assert ledger.account("1001")["ledger_balance"] == Decimal("1000.00")


def test_proximity_requires_device_token(pix):
    service, _, _, key = pix
    with pytest.raises(AuthorizationError):
        service.proximity("1001", key["key"], "10", "invalid", True)
    receipt = service.proximity("1001", key["key"], "10", "nfc_device", True)
    assert receipt["channel"] == "PROXIMITY"


def test_scheduled_and_recurring_pix_use_central_ledger(pix):
    service, ledger, db, key = pix
    when = (datetime.now(UTC) - timedelta(seconds=1)).isoformat()
    job = service.schedule_pix(
        "1001", key["key"], "10", when, "WEEKLY", (datetime.now(UTC) + timedelta(days=8)).isoformat()
    )
    assert service.run_scheduled() == {"processed": 1, "failed": 0}
    assert ledger.account("1002")["ledger_balance"] == Decimal("110.00")
    with db.connect() as con:
        assert (
            con.execute("SELECT state FROM scheduled_jobs WHERE job_id=?", (job,)).fetchone()[0] == "ACTIVE"
        )
