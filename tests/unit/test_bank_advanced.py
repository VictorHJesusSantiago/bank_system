from datetime import UTC, datetime
from decimal import Decimal

import pytest

from bank_advanced import (
    AdvancedBanking,
    validate_cnpj,
    validate_cpf,
    validate_email,
    validate_phone,
)
from bank_core import AuthorizationError, BankDatabase, BankError, LedgerService


@pytest.fixture
def advanced(tmp_path):
    db = BankDatabase(tmp_path / "advanced.db")
    ledger = LedgerService(db)
    ledger.create_account("1001", "customer-1", initial_balance="1000")
    return AdvancedBanking(db, ledger, b"K" * 32), db, ledger


def test_validators():
    assert validate_cpf("529.982.247-25")
    assert validate_cnpj("11.222.333/0001-81")
    assert validate_email("pessoa@example.com")
    assert validate_phone("(11) 99999-9999")
    assert not validate_cnpj("11.111.111/1111-11")


def test_vault_encrypt_rotate_and_tamper_detection(advanced):
    app, db, _ = advanced
    object_id = app.vault.encrypt("SECRET", "conteúdo", "owner")
    assert app.vault.decrypt(object_id) == "conteúdo".encode()
    assert app.vault.rotate() == 2
    assert app.vault.decrypt(object_id) == "conteúdo".encode()
    with db.transaction() as con:
        con.execute("UPDATE secure_objects SET digest='bad' WHERE object_id=?", (object_id,))
    with pytest.raises(BankError) as caught:
        app.vault.decrypt(object_id)
    assert caught.value.code == "TAMPERED_SECRET"


def test_tokenization_masking_pix_and_no_cvv(advanced):
    app, db, _ = advanced
    token1 = app.vault.tokenize_pan("4111111111111111")
    token2 = app.vault.tokenize_pan("4111111111111111")
    assert token1 == token2 and "411111" not in token1
    assert app.vault.mask("CPF", "52998224725") == "*******4725"
    assert app.vault.mask("CARD", "4111111111111111") == "**** **** **** 1111"
    assert app.vault.mask("EMAIL", "nome@example.com") == "n***@example.com"
    assert len(app.vault.cryptographic_pix_key()) == 36
    with db.connect() as con:
        columns = [row[1].lower() for row in con.execute("PRAGMA table_info(tokens)")]
    assert "cvv" not in columns
    first = app.vault.rotate_virtual_card("1001")
    second = app.vault.rotate_virtual_card("1001")
    assert first["pan"] != second["pan"] and first["cvv"] != second["cvv"]
    with db.connect() as con:
        assert con.execute("SELECT COUNT(*) FROM virtual_cards WHERE state='ACTIVE'").fetchone()[0] == 1
        assert "cvv" not in [row[1].lower() for row in con.execute("PRAGMA table_info(virtual_cards)")]


def test_encrypted_backup_and_automatic_restore_test(advanced, tmp_path):
    app, _, _ = advanced
    backup = app.vault.encrypted_backup(tmp_path / "backup.enc")
    assert backup.read_bytes().startswith(b"BANKENC2")
    assert b"SQLite format" not in backup.read_bytes()
    assert app.vault.test_restore(backup)


def test_legacy_v1_backup_is_still_restorable(advanced, tmp_path):
    """Backups BANKENC1 gravados antes da mudança de formato continuam válidos."""
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    import os

    app, _, _ = advanced
    plain = tmp_path / "plain.db"
    app.vault.db.backup(plain)
    legacy_key = app.vault.provider.exportable_material()
    nonce = os.urandom(12)
    legacy = tmp_path / "legacy.enc"
    legacy.write_bytes(
        b"BANKENC1" + nonce + AESGCM(legacy_key).encrypt(nonce, plain.read_bytes(), b"BANK-BACKUP")
    )
    assert app.vault.test_restore(legacy)
    assert not app.vault.test_restore(tmp_path / "plain.db")


def test_rate_limit_and_blocklist(advanced):
    app, _, _ = advanced
    app.fraud.rate_limit("user", "PIX", 2, 60)
    app.fraud.rate_limit("user", "PIX", 2, 60)
    with pytest.raises(AuthorizationError):
        app.fraud.rate_limit("user", "PIX", 2, 60)
    app.fraud.block("PIX", "blocked-key", "fraude")
    result = app.fraud.evaluate({"destination": "blocked-key", "amount": "1"})
    assert result["action"] == "BLOCK"


def test_fraud_velocity_context_rules_and_case(advanced):
    app, db, _ = advanced
    app.fraud.configure_rule("país bloqueado", 1, {"country": "XX"}, "BLOCK")
    assert (
        app.fraud.evaluate(
            {"amount": "9000", "usual_max": "1000", "trusted_device": False, "new_location": True}
        )["action"]
        == "BLOCK"
    )
    assert app.fraud.evaluate({"amount": "1", "country": "XX"})["action"] == "BLOCK"
    case = app.fraud.create_case(None, "1001", "HIGH", "comportamento", {"ip": "x"})
    with db.connect() as con:
        assert con.execute("SELECT status FROM fraud_cases WHERE case_id=?", (case,)).fetchone()[0] == "OPEN"
    app.fraud.resolve_case(case, "analyst", "CLOSED", "resolvido")
    assert app.fraud.dispute("tx", "user", "não reconhecida", {"file": "x"})


def test_beneficiary_cooling_trusted_device_street_and_duress(advanced):
    app, db, _ = advanced
    beneficiary = app.fraud.add_beneficiary("user", "dest", "Pessoa", cooling_hours=24)
    device = app.fraud.trust_device("user", "fingerprint", "Celular")
    app.fraud.set_street_mode("user", True, "150")
    app.fraud.set_duress_code("user", "987654")
    assert app.fraud.check_duress("user", "987654")
    with db.connect() as con:
        assert (
            con.execute("SELECT state FROM beneficiaries WHERE beneficiary_id=?", (beneficiary,)).fetchone()[
                0
            ]
            == "COOLING"
        )
        assert (
            con.execute("SELECT state FROM trusted_devices WHERE device_id=?", (device,)).fetchone()[0]
            == "TRUSTED"
        )
        assert (
            con.execute("SELECT preventive_block FROM security_profiles WHERE user_id='user'").fetchone()[0]
            == 1
        )


def valid_customer():
    return {
        "name": "Pessoa Teste",
        "document": "52998224725",
        "email": "pessoa@example.com",
        "phone": "11999999999",
        "nationality": "BR",
        "tax_residence": "BR",
        "occupation": "Analista",
        "income_source": "Salário",
        "address": "Rua Exemplo, 10",
        "social_name": "Pessoa",
        "identity": "123",
        "issuer": "SSP",
        "assets": "10000",
        "pep": False,
        "communication": ["EMAIL"],
        "tags": ["varejo"],
    }


def test_unified_customer_kyc_documents_consent_and_timeline(advanced):
    app, db, _ = advanced
    customer = app.kyc.create_customer(valid_customer())
    assert app.kyc.customer(customer)["pii"]["name"] == "Pessoa Teste"
    document = app.kyc.upload_document(customer, "identidade.pdf", b"PDF")
    assert app.vault.decrypt(document) == b"PDF"
    consent = app.kyc.consent(customer, "OPEN_FINANCE", "2.0")
    app.kyc.revoke_consent(consent)
    app.kyc.timeline(customer, "CONTACT", "Atendimento", "agent")
    with db.connect() as con:
        review = con.execute("SELECT review_id FROM kyc_reviews WHERE customer_id=?", (customer,)).fetchone()[
            0
        ]
    app.kyc.review(review, "APPROVED", "reviewer")
    assert app.kyc.customer(customer)["status"] == "ACTIVE"


def test_kyc_relations_beneficial_owner_and_complaint_sla(advanced):
    app, db, _ = advanced
    first = app.kyc.create_customer(valid_customer())
    second_data = valid_customer() | {
        "name": "Empresa",
        "document": "11222333000181",
        "email": "empresa@example.com",
    }
    second = app.kyc.create_customer(second_data)
    app.kyc.relate(second, first, "BENEFICIAL_OWNER", "75")
    protocol = app.kyc.complaint(first, "PIX", "Operação contestada", sla_hours=24)
    with db.connect() as con:
        row = con.execute("SELECT * FROM complaints WHERE protocol=?", (protocol,)).fetchone()
    assert row["status"] == "OPEN"
    assert datetime.fromisoformat(row["due_at"]) > datetime.now(UTC)


def test_account_products_joint_minor_packages_and_limits(advanced):
    app, db, _ = advanced
    app.accounts.configure(
        "1001", "JOINT", [("c1", "OWNER"), ("c2", "OWNER")], alias="Casa", joint_mode="ALL"
    )
    package = app.accounts.package("Essencial", "12.90", 10, {"salary": True, "investment_min": 100000})
    app.accounts.set_limit("1001", "MOBILE", "PIX", "1000", "5000", "10000")
    with db.transaction() as con:
        con.execute("UPDATE account_profiles SET package_id=? WHERE account_number='1001'", (package,))
    with pytest.raises(BankError):
        app.accounts.configure("1001", "MINOR", [("c1", "OWNER")])


def test_statement_search_ofx_and_blocks(advanced):
    app, _, ledger = advanced
    ledger.external_debit("1001", "20", "pay:1", "PAYMENT", "Conta de luz")
    rows = app.accounts.statement("1001", "2000-01-01", "2099-12-31", query="luz")
    assert len(rows) == 1
    assert "<OFX>" in app.accounts.export_ofx("1001", "2000-01-01", "2099-12-31")
    app.accounts.block("1001", "JUDICIAL", legal="100")
    assert ledger.account("1001")["blocked_balance"] == Decimal("100.00")


def test_account_closure_transfers_balance(advanced):
    app, _, ledger = advanced
    ledger.create_account("1002", "customer-2")
    app.accounts.configure("1001", "CHECKING", [("c1", "OWNER")])
    protocol = app.accounts.close("1001", "1002")
    assert protocol.startswith("ENC")
    assert ledger.account("1002")["ledger_balance"] == Decimal("1000.00")


def test_transaction_state_machine_receipt_metadata_and_timeout(advanced):
    app, _, _ = advanced
    tx = app.transactions.create(
        "PIX",
        "engine:1",
        "Transferência",
        "100",
        "1",
        "0.50",
        channel="MOBILE",
        device="phone",
        category="TRANSFER",
        tags=["urgent"],
        attachment=b"proof",
        location=("-23", "-46"),
    )
    app.transactions.transition(tx, "AUTHORIZED")
    app.transactions.transition(tx, "PROCESSING")
    app.transactions.transition(tx, "SETTLED")
    with app.transactions.db.connect() as con:
        code = con.execute(
            "SELECT receipt_code FROM transaction_details WHERE transaction_id=?", (tx,)
        ).fetchone()[0]
    assert app.transactions.receipt(code)["net_cents"] == 9850
    with pytest.raises(BankError):
        app.transactions.transition(tx, "CANCELLED")


def test_batches_holidays_and_idempotency(advanced):
    app, db, _ = advanced
    first = app.transactions.create("TED", "same-key", "A", "10")
    second = app.transactions.create("TED", "same-key", "A", "10")
    assert first == second
    batch = app.transactions.batch("PJ", [{"destination": "1", "amount": "10"}], approval_required=True)
    app.transactions.holidays("2026-12-25", "Natal")
    with db.connect() as con:
        assert (
            con.execute(
                "SELECT approval_required FROM transaction_batches WHERE batch_id=?", (batch,)
            ).fetchone()[0]
            == 1
        )


def test_batch_execution_with_pj_approval(advanced):
    app, _, ledger = advanced
    ledger.create_account("1002", "customer-2")
    batch = app.transactions.batch(
        "PJ", [{"origin": "1001", "destination": "1002", "amount": "25"}], approval_required=True
    )
    with pytest.raises(AuthorizationError):
        app.transactions.execute_batch(batch)
    assert app.transactions.execute_batch(batch, "approver") == {"settled": 1, "failed": 0}
    assert ledger.account("1002")["ledger_balance"] == Decimal("25.00")
