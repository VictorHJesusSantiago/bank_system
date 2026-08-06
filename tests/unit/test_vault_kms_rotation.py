"""ADR-001 passos 3 e 4: custódia em KMS e rotação da KEK.

O ponto de um KMS é que o material da KEK nunca entra no processo. Estes testes
verificam a propriedade, não só o caminho feliz: o provedor de KMS não expõe
material, a rotação reembrulha tudo sem tocar nos dados cifrados, e uma KEK
retirada deixa de abrir o cofre.
"""

import base64
import secrets

import pytest

from bank_advanced import (
    AdvancedBanking,
    EnvKeyProvider,
    ExplicitKeyProvider,
    InProcessKmsClient,
    KmsKeyProvider,
    VaultService,
)
from bank_core import BankDatabase, BankError, LedgerService


@pytest.fixture
def kms():
    client = InProcessKmsClient()
    client.create_key("alias/bank-kek-2026")
    return client


@pytest.fixture
def vault_on_kms(tmp_path, kms):
    db = BankDatabase(tmp_path / "kms.db")
    provider = KmsKeyProvider(kms, "alias/bank-kek-2026", version="kek-2026")
    return VaultService(db, key_provider=provider), db, provider


def test_kms_provider_never_exposes_key_material(vault_on_kms):
    """A propriedade que justifica o ADR: a KEK não é obtenível daqui."""
    _, _, provider = vault_on_kms
    assert provider.exportable_material() is None


def test_vault_encrypts_and_decrypts_through_kms(vault_on_kms, kms):
    vault, _, _ = vault_on_kms
    object_id = vault.encrypt("CUSTOMER_PII", "dados sensíveis")
    assert vault.decrypt(object_id) == "dados sensíveis".encode()
    assert "encrypt" in kms.calls and "decrypt" in kms.calls


def test_kms_wrap_is_bound_to_encryption_context(vault_on_kms, kms):
    """Envelope de uma chave não pode ser reaproveitado sob outro contexto."""
    _, _, provider = vault_on_kms
    wrapped = provider.wrap(secrets.token_bytes(32), "key-a")
    assert provider.unwrap(wrapped, "key-a")
    with pytest.raises(BankError) as exc:
        provider.unwrap(wrapped, "key-b")
    assert exc.value.code == "KMS_REJECTED"


def test_kms_transient_failure_is_retried(kms, tmp_path):
    """Falha transitória de rede não pode derrubar a decifragem."""

    class FlakyClient:
        def __init__(self, inner):
            self.inner, self.attempts = inner, 0

        def encrypt(self, **kwargs):
            self.attempts += 1
            if self.attempts < 3:
                raise ConnectionError("timeout transitório")
            return self.inner.encrypt(**kwargs)

        def decrypt(self, **kwargs):
            return self.inner.decrypt(**kwargs)

    flaky = FlakyClient(kms)
    provider = KmsKeyProvider(flaky, "alias/bank-kek-2026", version="kek-flaky")
    wrapped = provider.wrap(secrets.token_bytes(32), "ctx")
    assert flaky.attempts == 3 and provider.unwrap(wrapped, "ctx")


def test_kms_permanent_failure_surfaces_as_domain_error(kms):
    class DeadClient:
        def encrypt(self, **kwargs):
            raise ConnectionError("KMS fora do ar")

    provider = KmsKeyProvider(DeadClient(), "alias/x", version="kek-dead", max_attempts=2)
    with pytest.raises(BankError) as exc:
        provider.wrap(secrets.token_bytes(32), "ctx")
    assert exc.value.code == "KMS_UNAVAILABLE"


def test_kek_rotation_rewraps_keys_without_touching_ciphertext(vault_on_kms, kms):
    """Passo 4: rotacionar a KEK muda só o envelope, não os dados cifrados."""
    vault, db, _ = vault_on_kms
    object_id = vault.encrypt("CUSTOMER_PII", "não pode mudar")
    with db.connect() as con:
        before = con.execute(
            "SELECT ciphertext,nonce,key_id FROM secure_objects WHERE object_id=?",
            (object_id,),
        ).fetchone()
        wrapped_before = con.execute("SELECT wrapped_key FROM vault_keys").fetchone()[0]

    kms.create_key("alias/bank-kek-2027")
    report = vault.rotate_kek(KmsKeyProvider(kms, "alias/bank-kek-2027", version="kek-2027"))

    assert report["previous_kek_version"] == "kek-2026"
    assert report["current_kek_version"] == "kek-2027"
    assert report["rewrapped_keys"] >= 1

    with db.connect() as con:
        after = con.execute(
            "SELECT ciphertext,nonce,key_id FROM secure_objects WHERE object_id=?",
            (object_id,),
        ).fetchone()
        wrapped_after = con.execute("SELECT wrapped_key FROM vault_keys").fetchone()[0]

    assert after["ciphertext"] == before["ciphertext"]
    assert after["nonce"] == before["nonce"] and after["key_id"] == before["key_id"]
    assert wrapped_after != wrapped_before
    assert vault.decrypt(object_id) == "não pode mudar".encode()
    assert vault.kek_status()["fully_rotated"]


def test_old_kek_can_be_destroyed_after_rotation(vault_on_kms, kms):
    """A rotação só vale se permitir aposentar a KEK antiga de verdade.

    Em KMS simétrico o envelope carrega o id da chave e `Decrypt` a usa; a
    revogação acontece ao desabilitar/destruir a chave no KMS. Este teste prova
    que, terminada a rotação, destruir a KEK anterior não quebra nada — e que
    antes dela quebraria.
    """
    vault, _, _ = vault_on_kms
    object_id = vault.encrypt("CUSTOMER_PII", "segredo")
    kms.create_key("alias/bank-kek-2027")
    vault.rotate_kek(KmsKeyProvider(kms, "alias/bank-kek-2027", version="kek-2027"))

    del kms.keys["alias/bank-kek-2026"]
    assert vault.decrypt(object_id) == "segredo".encode()
    assert vault.kek_status()["fully_rotated"]


def test_destroying_the_kek_without_rotating_makes_data_unreadable(vault_on_kms, kms):
    """Contraprova do teste acima: sem rotação, o dado depende da KEK antiga."""
    vault, _, _ = vault_on_kms
    object_id = vault.encrypt("CUSTOMER_PII", "segredo")
    del kms.keys["alias/bank-kek-2026"]
    with pytest.raises(BankError) as exc:
        vault.decrypt(object_id)
    assert exc.value.code == "KMS_REJECTED"


def test_rotation_refuses_a_same_version_kek(vault_on_kms, kms):
    vault, _, _ = vault_on_kms
    with pytest.raises(BankError) as exc:
        vault.rotate_kek(KmsKeyProvider(kms, "alias/bank-kek-2026", version="kek-2026"))
    assert exc.value.code == "KEK_VERSION_UNCHANGED"


def test_rotation_from_local_kek_to_kms(tmp_path, kms):
    """A migração que o ADR-001 descreve: sair do arquivo/env e entrar no KMS."""
    db = BankDatabase(tmp_path / "migrate.db")
    local_key = secrets.token_bytes(32)
    vault = VaultService(db, key_provider=ExplicitKeyProvider(local_key))
    object_id = vault.encrypt("KYC_DOCUMENT", "documento")
    token_before = vault.tokenize_pan("4111111111111111")

    report = vault.rotate_kek(KmsKeyProvider(kms, "alias/bank-kek-2026", version="kek-2026"))

    assert report["rewrapped_secrets"] >= 1
    assert vault.decrypt(object_id) == b"documento"
    assert vault.tokenize_pan("4111111111111111") == token_before
    assert vault.provider.exportable_material() is None
    assert vault.kek_status()["fully_rotated"]


def test_backup_taken_under_kms_restores_under_kms(vault_on_kms, tmp_path):
    """Backup v2 carrega a DEK embrulhada: restaurar não exige KEK exportável."""
    vault, _, _ = vault_on_kms
    backup = vault.encrypted_backup(tmp_path / "kms-backup.enc")
    assert backup.read_bytes().startswith(b"BANKENC2")
    assert vault.test_restore(backup)


def test_legacy_backup_is_rejected_clearly_under_kms(vault_on_kms, tmp_path):
    """Sob KMS o formato v1 é indecifrável — e precisa dizer isso, não falhar mudo."""
    vault, _, _ = vault_on_kms
    legacy = tmp_path / "old.enc"
    legacy.write_bytes(b"BANKENC1" + secrets.token_bytes(64))
    with pytest.raises(BankError) as exc:
        vault.test_restore(legacy)
    assert exc.value.code == "LEGACY_BACKUP_UNSUPPORTED"


def test_pan_tokens_survive_kek_rotation_on_env_provider(tmp_path, monkeypatch, kms):
    """Regressão: o pepper era o material da chave mestra; sob KMS não existe."""
    key = secrets.token_bytes(32)
    monkeypatch.setenv(EnvKeyProvider.VARIABLE, base64.urlsafe_b64encode(key).decode())
    db = BankDatabase(tmp_path / "pan.db")
    ledger = LedgerService(db)
    advanced = AdvancedBanking(db, ledger)
    token = advanced.vault.tokenize_pan("5555444433332222")
    advanced.vault.rotate_kek(KmsKeyProvider(kms, "alias/bank-kek-2026", version="kek-2026"))
    assert advanced.vault.tokenize_pan("5555444433332222") == token


def test_kek_status_reports_pending_versions(vault_on_kms):
    vault, db, _ = vault_on_kms
    vault.encrypt("TEST", "x")
    vault.tokenize_pan("4111111111111111")
    status = vault.kek_status()
    assert status["current"] == "kek-2026" and status["fully_rotated"]
    assert status["secrets_by_kek_version"] == {"kek-2026": 1}
    with db.transaction() as con:
        con.execute("UPDATE vault_keys SET kek_version='kek-2019'")
    pending = vault.kek_status()
    assert not pending["fully_rotated"]
    assert pending["keys_by_kek_version"] == {"kek-2019": 1}
