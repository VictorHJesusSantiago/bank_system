"""Segurança, KYC, contas e transações avançadas do Banco COBOL."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import re
import secrets
import sqlite3
import tempfile
import time
import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from pathlib import Path
from xml.sax.saxutils import escape
from typing import Any, Iterable

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from bank_observability import LOGGER, METRICS
from bank_core import (
    AccountingError,
    AuthorizationError,
    BankDatabase,
    BankError,
    LedgerService,
    cents_to_money,
    hash_token,
    money_to_cents,
    utcnow,
)


TRANSITIONS = {
    "CREATED": {"AUTHORIZED", "FAILED", "CANCELLED"},
    "AUTHORIZED": {"RESERVED", "PROCESSING", "CANCELLED", "FAILED"},
    "RESERVED": {"PROCESSING", "CANCELLED", "FAILED"},
    "PROCESSING": {"SETTLED", "FAILED"},
    "FAILED": {"PROCESSING", "CANCELLED"},
    "SETTLED": {"REVERSED", "PARTIALLY_REVERSED"},
    "PARTIALLY_REVERSED": {"REVERSED", "PARTIALLY_REVERSED"},
    "CANCELLED": set(),
    "REVERSED": set(),
}


def validate_cpf(value: str) -> bool:
    digits = re.sub(r"\D", "", value)
    if len(digits) != 11 or len(set(digits)) == 1:
        return False
    for size in (9, 10):
        total = sum(int(digits[i]) * (size + 1 - i) for i in range(size))
        check = 0 if total % 11 < 2 else 11 - total % 11
        if check != int(digits[size]):
            return False
    return True


def validate_cnpj(value: str) -> bool:
    digits = re.sub(r"\D", "", value)
    if len(digits) != 14 or len(set(digits)) == 1:
        return False
    for length, weights in (
        (12, [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]),
        (13, [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]),
    ):
        rest = sum(int(digits[i]) * weights[i] for i in range(length)) % 11
        check = 0 if rest < 2 else 11 - rest
        if check != int(digits[length]):
            return False
    return True


def validate_email(value: str) -> bool:
    return bool(re.fullmatch(r"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", value))


def validate_phone(value: str) -> bool:
    digits = re.sub(r"\D", "", value)
    return len(digits) in {10, 11, 12, 13} and len(set(digits)) > 1


def sanitize_text(value: str, maximum: int = 255) -> str:
    if not isinstance(value, str) or "\x00" in value:
        raise BankError("INVALID_TEXT", "Texto inválido")
    return " ".join(value.strip().split())[:maximum]


class AdvancedSchema:
    def __init__(self, db: BankDatabase):
        self.db = db
        with db.transaction() as con:
            con.executescript(
                """
                CREATE TABLE IF NOT EXISTS vault_keys(
                  key_id TEXT PRIMARY KEY,version INTEGER UNIQUE NOT NULL,
                  wrapped_key BLOB NOT NULL,state TEXT NOT NULL,created_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS secure_objects(
                  object_id TEXT PRIMARY KEY,kind TEXT NOT NULL,key_id TEXT NOT NULL,
                  nonce BLOB NOT NULL,ciphertext BLOB NOT NULL,digest TEXT NOT NULL,
                  owner_id TEXT,created_at TEXT NOT NULL,
                  FOREIGN KEY(key_id) REFERENCES vault_keys(key_id));
                CREATE TABLE IF NOT EXISTS tokens(
                  token TEXT PRIMARY KEY,kind TEXT NOT NULL,digest TEXT UNIQUE NOT NULL,
                  last4 TEXT NOT NULL,secure_object_id TEXT NOT NULL,created_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS rate_events(
                  subject TEXT NOT NULL,operation TEXT NOT NULL,occurred_at TEXT NOT NULL);
                CREATE INDEX IF NOT EXISTS idx_rate ON rate_events(subject,operation,occurred_at);
                CREATE TABLE IF NOT EXISTS fraud_rules(
                  rule_id TEXT PRIMARY KEY,name TEXT NOT NULL,priority INTEGER NOT NULL,
                  expression TEXT NOT NULL,action TEXT NOT NULL,enabled INTEGER NOT NULL);
                CREATE TABLE IF NOT EXISTS blocklist(
                  value_hash TEXT PRIMARY KEY,kind TEXT NOT NULL,reason TEXT NOT NULL,
                  active INTEGER NOT NULL,created_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS trusted_devices(
                  device_id TEXT PRIMARY KEY,user_id TEXT NOT NULL,fingerprint TEXT NOT NULL,
                  name TEXT NOT NULL,state TEXT NOT NULL,last_seen TEXT NOT NULL,
                  UNIQUE(user_id,fingerprint));
                CREATE TABLE IF NOT EXISTS beneficiaries(
                  beneficiary_id TEXT PRIMARY KEY,user_id TEXT NOT NULL,
                  destination TEXT NOT NULL,name TEXT NOT NULL,state TEXT NOT NULL,
                  available_at TEXT NOT NULL,created_at TEXT NOT NULL,
                  UNIQUE(user_id,destination));
                CREATE TABLE IF NOT EXISTS fraud_cases(
                  case_id TEXT PRIMARY KEY,transaction_id TEXT,account_number TEXT,
                  severity TEXT NOT NULL,status TEXT NOT NULL,reason TEXT NOT NULL,
                  evidence TEXT NOT NULL,assigned_to TEXT,created_at TEXT NOT NULL,
                  updated_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS disputes(
                  dispute_id TEXT PRIMARY KEY,transaction_id TEXT NOT NULL,user_id TEXT NOT NULL,
                  reason TEXT NOT NULL,status TEXT NOT NULL,evidence TEXT NOT NULL,
                  resolution TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS security_profiles(
                  user_id TEXT PRIMARY KEY,street_mode INTEGER NOT NULL DEFAULT 0,
                  street_limit_cents INTEGER NOT NULL DEFAULT 20000,
                  duress_hash TEXT,preventive_block INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS customers(
                  customer_id TEXT PRIMARY KEY,document_hash TEXT UNIQUE NOT NULL,
                  document_type TEXT NOT NULL,pii_object_id TEXT NOT NULL,status TEXT NOT NULL,
                  risk TEXT NOT NULL,segment TEXT,tags TEXT NOT NULL,kyc_due_at TEXT,
                  created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS customer_relations(
                  relation_id TEXT PRIMARY KEY,source_id TEXT NOT NULL,target_id TEXT NOT NULL,
                  relation_type TEXT NOT NULL,percentage TEXT,valid_until TEXT);
                CREATE TABLE IF NOT EXISTS customer_products(
                  customer_id TEXT NOT NULL,product_type TEXT NOT NULL,product_id TEXT NOT NULL,
                  PRIMARY KEY(customer_id,product_type,product_id));
                CREATE TABLE IF NOT EXISTS kyc_reviews(
                  review_id TEXT PRIMARY KEY,customer_id TEXT NOT NULL,status TEXT NOT NULL,
                  checklist TEXT NOT NULL,reason TEXT,reviewer TEXT,
                  created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS consents(
                  consent_id TEXT PRIMARY KEY,customer_id TEXT NOT NULL,purpose TEXT NOT NULL,
                  version TEXT NOT NULL,state TEXT NOT NULL,granted_at TEXT NOT NULL,
                  revoked_at TEXT);
                CREATE TABLE IF NOT EXISTS timeline(
                  event_id TEXT PRIMARY KEY,customer_id TEXT NOT NULL,kind TEXT NOT NULL,
                  note TEXT NOT NULL,actor TEXT,created_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS complaints(
                  protocol TEXT PRIMARY KEY,customer_id TEXT NOT NULL,subject TEXT NOT NULL,
                  description TEXT NOT NULL,status TEXT NOT NULL,priority TEXT NOT NULL,
                  due_at TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS account_profiles(
                  account_number TEXT PRIMARY KEY,alias TEXT,product TEXT NOT NULL,
                  joint_mode TEXT,package_id TEXT,currency TEXT NOT NULL DEFAULT 'BRL',
                  parent_account TEXT,legal_block_cents INTEGER NOT NULL DEFAULT 0,
                  guarantee_block_cents INTEGER NOT NULL DEFAULT 0,
                  block_reason TEXT,closure_state TEXT,closure_protocol TEXT);
                CREATE TABLE IF NOT EXISTS account_owners(
                  account_number TEXT NOT NULL,customer_id TEXT NOT NULL,role TEXT NOT NULL,
                  approval_required INTEGER NOT NULL DEFAULT 0,
                  PRIMARY KEY(account_number,customer_id));
                CREATE TABLE IF NOT EXISTS service_packages(
                  package_id TEXT PRIMARY KEY,name TEXT NOT NULL,monthly_fee_cents INTEGER NOT NULL,
                  included_operations INTEGER NOT NULL,exemption_rule TEXT NOT NULL,active INTEGER NOT NULL);
                CREATE TABLE IF NOT EXISTS operation_limits(
                  account_number TEXT NOT NULL,channel TEXT NOT NULL,operation TEXT NOT NULL,
                  daily_cents INTEGER,weekly_cents INTEGER,monthly_cents INTEGER,
                  effective_at TEXT NOT NULL,state TEXT NOT NULL,
                  PRIMARY KEY(account_number,channel,operation));
                CREATE TABLE IF NOT EXISTS transaction_details(
                  transaction_id TEXT PRIMARY KEY,engine_state TEXT NOT NULL,failure_code TEXT,
                  failure_reason TEXT,attempts INTEGER NOT NULL DEFAULT 0,timeout_at TEXT,
                  category TEXT,tags TEXT NOT NULL,attachment_object_id TEXT,latitude TEXT,
                  longitude TEXT,channel TEXT,device TEXT,gross_cents INTEGER NOT NULL,
                  fee_cents INTEGER NOT NULL,tax_cents INTEGER NOT NULL,net_cents INTEGER NOT NULL,
                  receipt_code TEXT UNIQUE,administrative_reason TEXT,updated_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS transaction_batches(
                  batch_id TEXT PRIMARY KEY,owner_id TEXT NOT NULL,state TEXT NOT NULL,
                  approval_required INTEGER NOT NULL,approved_by TEXT,created_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS batch_items(
                  batch_id TEXT NOT NULL,item_no INTEGER NOT NULL,payload TEXT NOT NULL,
                  state TEXT NOT NULL,transaction_id TEXT,error TEXT,
                  PRIMARY KEY(batch_id,item_no));
                CREATE TABLE IF NOT EXISTS holidays(day TEXT PRIMARY KEY,name TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS virtual_cards(
                  card_id TEXT PRIMARY KEY,account_number TEXT NOT NULL,pan_token TEXT NOT NULL,
                  state TEXT NOT NULL,expires_at TEXT NOT NULL,created_at TEXT NOT NULL,revoked_at TEXT);
                CREATE TABLE IF NOT EXISTS account_events(
                  event_id TEXT PRIMARY KEY,account_number TEXT NOT NULL,kind TEXT NOT NULL,
                  amount_cents INTEGER NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL);
                """
            )


class KeyProvider:
    """Custódia da KEK (ADR-001).

    A interface é ``wrap``/``unwrap``, e não "me devolva a chave", porque um
    HSM/KMS real nunca entrega o material da KEK: as operações acontecem dentro
    do provedor. Qualquer abstração que exponha ``master_key() -> bytes``
    exclui, por construção, a única custódia que resolve o problema.

    ``version`` identifica a KEK vigente e é gravado junto de cada chave
    embrulhada, para que a rotação saiba o que ainda falta reembrulhar.
    """

    version: str = "unversioned"

    def wrap(self, dek: bytes, context: str) -> bytes:
        """Embrulha uma DEK. ``context`` é dado autenticado (AAD/EncryptionContext)."""
        raise NotImplementedError

    def unwrap(self, wrapped: bytes, context: str) -> bytes:
        raise NotImplementedError

    def exportable_material(self) -> bytes | None:
        """Material da KEK, quando o provedor o possui localmente.

        Existe apenas para compatibilidade com dados legados (tokens de PAN e
        backups ``BANKENC1`` derivados diretamente da chave mestra). Um provedor
        de KMS devolve ``None`` — e é esse o comportamento desejável.
        """
        return None

    @staticmethod
    def _validate(key: bytes) -> bytes:
        if len(key) != 32:
            raise BankError("INVALID_MASTER_KEY", "Chave mestra deve possuir 256 bits")
        return key


class LocalKeyProvider(KeyProvider):
    """Base dos provedores que mantêm a KEK no processo.

    O formato embrulhado (``nonce || AES-GCM(dek)``, AAD = contexto) é o mesmo
    de antes da introdução de ``KeyProvider``: bancos existentes continuam
    legíveis sem migração de dados.
    """

    def __init__(self, key: bytes, version: str = "local-v1"):
        self._key = self._validate(key)
        self.version = version

    def wrap(self, dek: bytes, context: str) -> bytes:
        nonce = os.urandom(12)
        return nonce + AESGCM(self._key).encrypt(nonce, dek, context.encode())

    def unwrap(self, wrapped: bytes, context: str) -> bytes:
        return AESGCM(self._key).decrypt(wrapped[:12], wrapped[12:], context.encode())

    def exportable_material(self) -> bytes | None:
        return self._key


class ExplicitKeyProvider(LocalKeyProvider):
    """KEK fornecida pelo chamador — usada por testes e por embutidores."""


class EnvKeyProvider(LocalKeyProvider):
    """KEK em ``BANK_MASTER_KEY``. Aceitável em homologação, não em produção."""

    VARIABLE = "BANK_MASTER_KEY"

    def __init__(self) -> None:
        raw = os.environ.get(self.VARIABLE)
        if not raw:
            raise BankError("MASTER_KEY_UNAVAILABLE", f"{self.VARIABLE} não definida")
        super().__init__(base64.urlsafe_b64decode(raw), version="env-v1")

    @classmethod
    def available(cls) -> bool:
        return bool(os.environ.get(cls.VARIABLE))


class LocalFileKeyProvider(LocalKeyProvider):
    """KEK em arquivo ao lado do banco — inseguro por construção (ADR-001).

    Gravar a chave junto do dado cifrado anula a criptografia em repouso: quem
    copia o diretório leva as duas coisas. Por isso a criação automática exige
    ``BANK_ALLOW_INSECURE_LOCAL_KEY=1`` e avisa a cada inicialização.
    """

    OPT_IN = "BANK_ALLOW_INSECURE_LOCAL_KEY"

    def __init__(self, path: Path):
        self.path = path
        super().__init__(self._load_or_create(), version="file-v1")

    def _load_or_create(self) -> bytes:
        if self.path.exists():
            LOGGER.warning("vault.insecure_local_key", extra={"path": str(self.path)})
            return self.path.read_bytes()
        if os.environ.get(self.OPT_IN) != "1":
            raise BankError(
                "MASTER_KEY_UNAVAILABLE",
                "Nenhuma chave mestra disponível. Configure BANK_MASTER_KEY (ou um "
                f"KeyProvider) ou defina {self.OPT_IN}=1 para gerar uma chave local "
                "insegura em desenvolvimento (ver docs/adr/ADR-001).",
            )
        key = AESGCM.generate_key(bit_length=256)
        self.path.write_bytes(key)
        try:
            os.chmod(self.path, 0o600)
        except OSError:  # pragma: no cover - Windows não aplica modo POSIX
            pass
        LOGGER.warning("vault.generated_insecure_local_key", extra={"path": str(self.path)})
        return key


class KmsKeyProvider(KeyProvider):
    """KEK custodiada por um KMS/HSM externo (ADR-001, passo 3).

    O material da KEK nunca entra neste processo: ``wrap``/``unwrap`` são
    chamadas remotas e só DEKs (já embrulhadas ou em memória por instantes)
    circulam aqui. ``exportable_material`` devolve ``None`` — é o ponto da
    decisão.

    ``client`` segue o contrato do KMS da AWS (boto3 ``client("kms")``):

        client.encrypt(KeyId=..., Plaintext=..., EncryptionContext={...})
            -> {"CiphertextBlob": bytes}
        client.decrypt(CiphertextBlob=..., EncryptionContext={...})
            -> {"Plaintext": bytes, "KeyId": str}

    Qualquer objeto que implemente esse contrato serve — inclusive
    ``InProcessKmsClient``, usado nos testes e no desenvolvimento local, e um
    cliente do Vault/Cloud KMS envolvido por um adaptador fino.
    """

    CONTEXT_FIELD = "bank_context"

    def __init__(self, client: Any, key_id: str, version: str | None = None, max_attempts: int = 3):
        self.client = client
        self.key_id = key_id
        self.version = version or f"kms:{key_id}"
        self.max_attempts = max_attempts

    def _encryption_context(self, context: str) -> dict[str, str]:
        return {self.CONTEXT_FIELD: context}

    PERMANENT_ERRORS = (InvalidTag, KeyError, ValueError)

    def _call(self, operation: str, **kwargs: Any) -> dict[str, Any]:
        """Chamada ao KMS com retentativa e backoff exponencial.

        É I/O de rede em caminho crítico: uma falha transitória não pode
        derrubar a decifragem, mas uma falha permanente precisa falhar rápido.
        """
        last: Exception | None = None
        for attempt in range(1, self.max_attempts + 1):
            try:
                with METRICS.timer("kms_call_duration_ms", operation=operation):
                    return getattr(self.client, operation)(**kwargs)
            except self.PERMANENT_ERRORS as exc:
                METRICS.increment("kms_call_failures_total", operation=operation, reason="permanent")
                LOGGER.error(
                    "vault.kms_permanent_failure",
                    extra={"operation": operation, "error": type(exc).__name__},
                )
                raise BankError(
                    "KMS_REJECTED",
                    f"KMS rejeitou {operation}: chave ou contexto inválido",
                ) from exc
            except Exception as exc:  # noqa: BLE001 - erro do SDK é opaco por natureza
                last = exc
                METRICS.increment("kms_call_failures_total", operation=operation, reason="transient")
                LOGGER.warning(
                    "vault.kms_call_failed",
                    extra={"operation": operation, "attempt": attempt, "error": type(exc).__name__},
                )
                if attempt < self.max_attempts:
                    time.sleep(0.05 * 2 ** (attempt - 1))
        raise BankError("KMS_UNAVAILABLE", f"KMS indisponível em {operation}") from last

    def wrap(self, dek: bytes, context: str) -> bytes:
        response = self._call(
            "encrypt",
            KeyId=self.key_id,
            Plaintext=dek,
            EncryptionContext=self._encryption_context(context),
        )
        return response["CiphertextBlob"]

    def unwrap(self, wrapped: bytes, context: str) -> bytes:
        response = self._call(
            "decrypt",
            CiphertextBlob=wrapped,
            EncryptionContext=self._encryption_context(context),
        )
        return response["Plaintext"]


class InProcessKmsClient:
    """Implementação de referência do contrato KMS, para teste e desenvolvimento.

    Reproduz as propriedades que importam ao código chamador: envelope opaco,
    contexto de criptografia autenticado e erro quando a chave não existe. NÃO
    é um KMS — a chave vive no processo. Serve para exercitar
    ``KmsKeyProvider`` de verdade sem provisionar infraestrutura.
    """

    def __init__(self, keys: dict[str, bytes] | None = None):
        self.keys: dict[str, bytes] = dict(keys or {})
        self.calls: list[str] = []

    def create_key(self, key_id: str) -> str:
        self.keys[key_id] = AESGCM.generate_key(bit_length=256)
        return key_id

    def _material(self, key_id: str) -> bytes:
        if key_id not in self.keys:
            raise KeyError(f"chave KMS inexistente: {key_id}")
        return self.keys[key_id]

    @staticmethod
    def _aad(context: dict[str, str]) -> bytes:
        return json.dumps(context or {}, sort_keys=True).encode()

    def encrypt(
        self,
        *,
        KeyId: str,
        Plaintext: bytes,  # noqa: N803 - contrato do SDK
        EncryptionContext: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        self.calls.append("encrypt")
        nonce = os.urandom(12)
        blob = AESGCM(self._material(KeyId)).encrypt(nonce, Plaintext, self._aad(EncryptionContext or {}))
        return {"CiphertextBlob": KeyId.encode() + b"\x00" + nonce + blob, "KeyId": KeyId}

    def decrypt(
        self,
        *,
        CiphertextBlob: bytes,  # noqa: N803 - contrato do SDK
        EncryptionContext: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        self.calls.append("decrypt")
        key_id, _, rest = CiphertextBlob.partition(b"\x00")
        plaintext = AESGCM(self._material(key_id.decode())).decrypt(
            rest[:12], rest[12:], self._aad(EncryptionContext or {})
        )
        return {"Plaintext": plaintext, "KeyId": key_id.decode()}


def default_key_provider(db_path: Path) -> KeyProvider:
    """Ambiente decide a custódia: variável de ambiente antes do arquivo local."""
    if EnvKeyProvider.available():
        return EnvKeyProvider()
    return LocalFileKeyProvider(db_path.with_suffix(".master.key"))


class VaultService:
    PAN_PEPPER = "PAN_TOKENIZATION_PEPPER"
    BACKUP_KEY = "BACKUP_ENCRYPTION_KEY"

    def __init__(
        self, db: BankDatabase, master_key: bytes | None = None, key_provider: KeyProvider | None = None
    ):
        self.db = db
        AdvancedSchema(db)
        self.provider = (
            ExplicitKeyProvider(master_key)
            if master_key is not None
            else key_provider or default_key_provider(db.path)
        )
        self._migrate()
        self._ensure_key()

    def _migrate(self) -> None:
        """Expand: colunas e tabelas novas, sem reescrever dado existente."""
        with self.db.transaction() as con:
            columns = {row["name"] for row in con.execute("PRAGMA table_info(vault_keys)")}
            if "kek_version" not in columns:
                con.execute("ALTER TABLE vault_keys ADD COLUMN kek_version TEXT NOT NULL DEFAULT 'legacy'")
            con.execute(
                """CREATE TABLE IF NOT EXISTS vault_secrets(
                     name TEXT PRIMARY KEY, wrapped BLOB NOT NULL,
                     kek_version TEXT NOT NULL, created_at TEXT NOT NULL)"""
            )

    def _ensure_key(self) -> None:
        with self.db.transaction() as con:
            if con.execute("SELECT 1 FROM vault_keys WHERE state='ACTIVE'").fetchone():
                return
            self._insert_key(con, 1)

    def _insert_key(self, con: sqlite3.Connection, version: int) -> str:
        key_id, dek = str(uuid.uuid4()), AESGCM.generate_key(bit_length=256)
        wrapped = self.provider.wrap(dek, key_id)
        con.execute(
            "INSERT INTO vault_keys(key_id,version,wrapped_key,state,created_at,kek_version)"
            " VALUES(?,?,?,?,?,?)",
            (key_id, version, wrapped, "ACTIVE", utcnow(), self.provider.version),
        )
        return key_id

    def _dek(self, con: sqlite3.Connection, key_id: str) -> bytes:
        wrapped = con.execute("SELECT wrapped_key FROM vault_keys WHERE key_id=?", (key_id,)).fetchone()[0]
        return self.provider.unwrap(wrapped, key_id)

    def _secret(self, name: str) -> bytes:
        """Segredo nomeado, embrulhado pela KEK e estável entre reinícios.

        A tokenização de PAN e a cifra de backup usavam o material da chave
        mestra diretamente — impossível sob KMS, onde esse material não existe
        no processo. Passam a usar segredos próprios guardados aqui.
        """
        with self.db.connect() as con:
            row = con.execute("SELECT wrapped FROM vault_secrets WHERE name=?", (name,)).fetchone()
        if row:
            return self.provider.unwrap(row[0], name)
        legacy = self.provider.exportable_material()
        if legacy and name == self.PAN_PEPPER:
            material = legacy
        elif legacy:
            material = hashlib.sha256(legacy + name.encode()).digest()
        else:
            material = AESGCM.generate_key(bit_length=256)
        with self.db.transaction() as con:
            con.execute(
                "INSERT OR IGNORE INTO vault_secrets VALUES(?,?,?,?)",
                (name, self.provider.wrap(material, name), self.provider.version, utcnow()),
            )
            stored = con.execute("SELECT wrapped FROM vault_secrets WHERE name=?", (name,)).fetchone()[0]
        return self.provider.unwrap(stored, name)

    def rotate_kek(self, new_provider: KeyProvider) -> dict[str, Any]:
        """Rotaciona a KEK reembrulhando DEKs e segredos (ADR-001, passo 4).

        ``secure_objects`` NÃO é tocado: só o envelope muda, então o custo é
        proporcional ao número de chaves, não ao volume de dados cifrados.
        Exige os dois provedores ao mesmo tempo — o antigo para desembrulhar, o
        novo para embrulhar. Tudo em uma transação: ou toda a rotação vale, ou
        nenhuma parte dela.
        """
        if new_provider.version == self.provider.version:
            raise BankError("KEK_VERSION_UNCHANGED", "A nova KEK deve ter versão distinta da atual")
        rotated_keys = rotated_secrets = 0
        with self.db.transaction() as con:
            for row in con.execute("SELECT key_id,wrapped_key FROM vault_keys").fetchall():
                dek = self.provider.unwrap(row["wrapped_key"], row["key_id"])
                con.execute(
                    "UPDATE vault_keys SET wrapped_key=?,kek_version=? WHERE key_id=?",
                    (new_provider.wrap(dek, row["key_id"]), new_provider.version, row["key_id"]),
                )
                rotated_keys += 1
            for row in con.execute("SELECT name,wrapped FROM vault_secrets").fetchall():
                secret = self.provider.unwrap(row["wrapped"], row["name"])
                con.execute(
                    "UPDATE vault_secrets SET wrapped=?,kek_version=? WHERE name=?",
                    (new_provider.wrap(secret, row["name"]), new_provider.version, row["name"]),
                )
                rotated_secrets += 1
        previous = self.provider.version
        self.provider = new_provider
        LOGGER.warning(
            "vault.kek_rotated",
            extra={
                "from_version": previous,
                "to_version": new_provider.version,
                "keys": rotated_keys,
                "secrets": rotated_secrets,
            },
        )
        METRICS.increment("vault_kek_rotations_total")
        return {
            "previous_kek_version": previous,
            "current_kek_version": new_provider.version,
            "rewrapped_keys": rotated_keys,
            "rewrapped_secrets": rotated_secrets,
        }

    def kek_status(self) -> dict[str, Any]:
        """Quais versões de KEK ainda embrulham material — verificável em CI."""
        with self.db.connect() as con:
            keys = con.execute(
                "SELECT kek_version, COUNT(*) AS total FROM vault_keys GROUP BY kek_version"
            ).fetchall()
            secrets_rows = con.execute(
                "SELECT kek_version, COUNT(*) AS total FROM vault_secrets GROUP BY kek_version"
            ).fetchall()
        versions = {row["kek_version"] for row in keys} | {row["kek_version"] for row in secrets_rows}
        return {
            "current": self.provider.version,
            "keys_by_kek_version": {row["kek_version"]: row["total"] for row in keys},
            "secrets_by_kek_version": {row["kek_version"]: row["total"] for row in secrets_rows},
            "fully_rotated": versions <= {self.provider.version},
        }

    def encrypt(self, kind: str, data: bytes | str, owner_id: str | None = None) -> str:
        raw = data.encode() if isinstance(data, str) else data
        object_id, nonce = str(uuid.uuid4()), os.urandom(12)
        with self.db.transaction() as con:
            key_id = con.execute("SELECT key_id FROM vault_keys WHERE state='ACTIVE'").fetchone()[0]
            cipher = AESGCM(self._dek(con, key_id)).encrypt(nonce, raw, object_id.encode())
            con.execute(
                "INSERT INTO secure_objects VALUES(?,?,?,?,?,?,?,?)",
                (object_id, kind, key_id, nonce, cipher, hashlib.sha256(raw).hexdigest(), owner_id, utcnow()),
            )
        return object_id

    def decrypt(self, object_id: str) -> bytes:
        with self.db.connect() as con:
            row = con.execute("SELECT * FROM secure_objects WHERE object_id=?", (object_id,)).fetchone()
            if not row:
                raise BankError("SECRET_NOT_FOUND", "Objeto seguro não encontrado")
            raw = AESGCM(self._dek(con, row["key_id"])).decrypt(
                row["nonce"], row["ciphertext"], object_id.encode()
            )
        if not hmac.compare_digest(hashlib.sha256(raw).hexdigest(), row["digest"]):
            raise BankError("TAMPERED_SECRET", "Objeto seguro adulterado")
        return raw

    def rotate(self) -> int:
        with self.db.transaction() as con:
            version = con.execute("SELECT COALESCE(MAX(version),0)+1 FROM vault_keys").fetchone()[0]
            con.execute("UPDATE vault_keys SET state='RETIRED' WHERE state='ACTIVE'")
            new_id = self._insert_key(con, version)
            rows = con.execute("SELECT * FROM secure_objects").fetchall()
            new_dek = self._dek(con, new_id)
            for row in rows:
                raw = AESGCM(self._dek(con, row["key_id"])).decrypt(
                    row["nonce"], row["ciphertext"], row["object_id"].encode()
                )
                nonce = os.urandom(12)
                cipher = AESGCM(new_dek).encrypt(nonce, raw, row["object_id"].encode())
                con.execute(
                    "UPDATE secure_objects SET key_id=?,nonce=?,ciphertext=? WHERE object_id=?",
                    (new_id, nonce, cipher, row["object_id"]),
                )
        return version

    def tokenize_pan(self, pan: str) -> str:
        digits = re.sub(r"\D", "", pan)
        if len(digits) not in range(13, 20):
            raise BankError("INVALID_PAN", "Cartão inválido")
        digest = hmac.new(self._secret(self.PAN_PEPPER), digits.encode(), hashlib.sha256).hexdigest()
        with self.db.connect() as con:
            row = con.execute("SELECT token FROM tokens WHERE digest=?", (digest,)).fetchone()
            if row:
                return row[0]
        token = "tok_" + secrets.token_urlsafe(24)
        object_id = self.encrypt("PAN", digits)
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO tokens VALUES(?,?,?,?,?,?)",
                (token, "PAN", digest, digits[-4:], object_id, utcnow()),
            )
        return token

    def cryptographic_pix_key(self) -> str:
        return str(uuid.UUID(bytes=secrets.token_bytes(16), version=4))

    def rotate_virtual_card(self, account_number: str, validity_minutes: int = 30) -> dict[str, str]:
        prefix = "499999" + "".join(str(secrets.randbelow(10)) for _ in range(9))
        total = sum(
            (
                int(ch) * (2 if index % 2 == 0 else 1) - 9
                if int(ch) * (2 if index % 2 == 0 else 1) > 9
                else int(ch) * (2 if index % 2 == 0 else 1)
            )
            for index, ch in enumerate(prefix)
        )
        pan = prefix + str((10 - total % 10) % 10)
        token, card_id, now = self.tokenize_pan(pan), str(uuid.uuid4()), utcnow()
        expires = (datetime.now(UTC) + timedelta(minutes=validity_minutes)).isoformat()
        with self.db.transaction() as con:
            con.execute(
                "UPDATE virtual_cards SET state='REVOKED',revoked_at=? WHERE account_number=? AND state='ACTIVE'",
                (now, account_number),
            )
            con.execute(
                "INSERT INTO virtual_cards VALUES(?,?,?,?,?,?,?)",
                (card_id, account_number, token, "ACTIVE", expires, now, None),
            )
        return {
            "card_id": card_id,
            "pan": pan,
            "cvv": f"{secrets.randbelow(1000):03d}",
            "expires_at": expires,
        }

    BACKUP_MAGIC_V1 = b"BANKENC1"
    BACKUP_MAGIC_V2 = b"BANKENC2"

    def encrypted_backup(self, destination: str | Path) -> Path:
        destination = Path(destination)
        destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory() as temp:
            plain = Path(temp) / "core.db"
            self.db.backup(plain)
            dek = AESGCM.generate_key(bit_length=256)
            wrapped = self.provider.wrap(dek, "BANK-BACKUP")
            nonce = os.urandom(12)
            body = AESGCM(dek).encrypt(nonce, plain.read_bytes(), b"BANK-BACKUP")
            destination.write_bytes(
                self.BACKUP_MAGIC_V2 + len(wrapped).to_bytes(4, "big") + wrapped + nonce + body
            )
        return destination

    def _decrypt_backup(self, raw: bytes) -> bytes | None:
        if raw[:8] == self.BACKUP_MAGIC_V2:
            size = int.from_bytes(raw[8:12], "big")
            wrapped, rest = raw[12 : 12 + size], raw[12 + size :]
            dek = self.provider.unwrap(wrapped, "BANK-BACKUP")
            return AESGCM(dek).decrypt(rest[:12], rest[12:], b"BANK-BACKUP")
        if raw[:8] == self.BACKUP_MAGIC_V1:
            legacy = self.provider.exportable_material()
            if legacy is None:
                raise BankError(
                    "LEGACY_BACKUP_UNSUPPORTED",
                    "Backup BANKENC1 exige KEK exportável; regrave-o como BANKENC2 antes de migrar para KMS",
                )
            return AESGCM(legacy).decrypt(raw[8:20], raw[20:], b"BANK-BACKUP")
        return None

    def test_restore(self, backup: str | Path) -> bool:
        raw = Path(backup).read_bytes()
        plain = self._decrypt_backup(raw)
        if plain is None:
            return False
        with tempfile.TemporaryDirectory() as temp:
            restored = Path(temp) / "restore.db"
            restored.write_bytes(plain)
            con = sqlite3.connect(restored)
            try:
                return con.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
            finally:
                con.close()

    @staticmethod
    def mask(kind: str, value: str) -> str:
        if kind in {"CPF", "CNPJ"}:
            digits = re.sub(r"\D", "", value)
            return "*" * max(0, len(digits) - 4) + digits[-4:]
        if kind == "CARD":
            digits = re.sub(r"\D", "", value)
            return "**** **** **** " + digits[-4:]
        if kind == "EMAIL":
            local, domain = value.split("@", 1)
            return local[:1] + "***@" + domain
        if kind == "PHONE":
            digits = re.sub(r"\D", "", value)
            return "*" * max(0, len(digits) - 4) + digits[-4:]
        return "***"


class FraudService:
    def __init__(self, db: BankDatabase):
        self.db = db
        AdvancedSchema(db)

    def rate_limit(self, subject: str, operation: str, limit: int, window_seconds: int) -> None:
        cutoff = (datetime.now(UTC) - timedelta(seconds=window_seconds)).isoformat()
        with self.db.transaction() as con:
            con.execute(
                "DELETE FROM rate_events WHERE subject=? AND operation=? AND occurred_at<?",
                (hash_token(subject), operation, cutoff),
            )
            count = con.execute(
                "SELECT COUNT(*) FROM rate_events WHERE subject=? AND operation=? AND occurred_at>=?",
                (hash_token(subject), operation, cutoff),
            ).fetchone()[0]
            if count >= limit:
                raise AuthorizationError("RATE_LIMITED", "Limite de tentativas excedido")
            con.execute("INSERT INTO rate_events VALUES(?,?,?)", (hash_token(subject), operation, utcnow()))

    def add_beneficiary(self, user_id: str, destination: str, name: str, cooling_hours: int = 24) -> str:
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO beneficiaries VALUES(?,?,?,?,?,?,?)",
                (
                    identifier,
                    user_id,
                    destination,
                    sanitize_text(name, 100),
                    "COOLING",
                    (datetime.now(UTC) + timedelta(hours=cooling_hours)).isoformat(),
                    utcnow(),
                ),
            )
        return identifier

    def trust_device(self, user_id: str, fingerprint: str, name: str) -> str:
        device_id = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                """INSERT INTO trusted_devices VALUES(?,?,?,?,?,?)
              ON CONFLICT(user_id,fingerprint) DO UPDATE SET state='TRUSTED',last_seen=excluded.last_seen""",
                (device_id, user_id, hash_token(fingerprint), sanitize_text(name, 80), "TRUSTED", utcnow()),
            )
        return device_id

    def block(self, kind: str, value: str, reason: str) -> None:
        with self.db.transaction() as con:
            con.execute(
                "INSERT OR REPLACE INTO blocklist VALUES(?,?,?,?,?)",
                (hash_token(value), kind, sanitize_text(reason), 1, utcnow()),
            )

    def configure_rule(self, name: str, priority: int, expression: dict[str, Any], action: str) -> str:
        if action not in {"ALLOW", "REVIEW", "BLOCK", "CHALLENGE"}:
            raise BankError("INVALID_RULE", "Ação antifraude inválida")
        rule_id = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO fraud_rules VALUES(?,?,?,?,?,1)",
                (rule_id, sanitize_text(name), priority, json.dumps(expression), action),
            )
        return rule_id

    def evaluate(self, context: dict[str, Any]) -> dict[str, Any]:
        reasons, score, action = [], 0, "ALLOW"
        amount = money_to_cents(context.get("amount", 0))
        hour = int(context.get("hour", datetime.now(UTC).hour))
        with self.db.connect() as con:
            if con.execute(
                "SELECT 1 FROM blocklist WHERE value_hash=? AND active=1",
                (hash_token(str(context.get("destination", ""))),),
            ).fetchone():
                return {"action": "BLOCK", "score": 1000, "reasons": ["BLOCKLIST"]}
            rules = con.execute("SELECT * FROM fraud_rules WHERE enabled=1 ORDER BY priority").fetchall()
        if amount > money_to_cents(context.get("usual_max", "5000")):
            score += 35
            reasons.append("ATYPICAL_VALUE")
        if hour < 6 or hour >= 22:
            score += 20
            reasons.append("ATYPICAL_TIME")
        if not context.get("trusted_device", False):
            score += 25
            reasons.append("NEW_DEVICE")
        if context.get("new_location", False):
            score += 20
            reasons.append("NEW_LOCATION")
        for rule in rules:
            expr = json.loads(rule["expression"])
            if all(context.get(key) == value for key, value in expr.items()):
                action, reasons = rule["action"], reasons + [rule["name"]]
                break
        if action == "ALLOW":
            action = (
                "BLOCK"
                if score >= 70
                else "REVIEW"
                if score >= 40
                else "CHALLENGE"
                if score >= 20
                else "ALLOW"
            )
        return {"action": action, "score": score, "reasons": reasons}

    def create_case(
        self, transaction_id: str | None, account: str, severity: str, reason: str, evidence: dict[str, Any]
    ) -> str:
        case_id, now = str(uuid.uuid4()), utcnow()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO fraud_cases VALUES(?,?,?,?,?,?,?,?,?,?)",
                (
                    case_id,
                    transaction_id,
                    account,
                    severity,
                    "OPEN",
                    sanitize_text(reason),
                    json.dumps(evidence),
                    None,
                    now,
                    now,
                ),
            )
        return case_id

    def dispute(self, transaction_id: str, user_id: str, reason: str, evidence: dict[str, Any]) -> str:
        identifier, now = str(uuid.uuid4()), utcnow()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO disputes VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    identifier,
                    transaction_id,
                    user_id,
                    sanitize_text(reason),
                    "OPEN",
                    json.dumps(evidence),
                    None,
                    now,
                    now,
                ),
            )
        return identifier

    def resolve_case(self, case_id: str, analyst: str, status: str, note: str) -> None:
        if status not in {"UNDER_REVIEW", "CONFIRMED", "DISMISSED", "CLOSED"}:
            raise BankError("INVALID_CASE_STATE", "Estado inválido")
        with self.db.transaction() as con:
            row = con.execute("SELECT evidence FROM fraud_cases WHERE case_id=?", (case_id,)).fetchone()
            if not row:
                raise BankError("CASE_NOT_FOUND", "Caso não encontrado")
            evidence = json.loads(row[0])
            evidence.setdefault("notes", []).append(
                {"analyst": analyst, "note": sanitize_text(note), "at": utcnow()}
            )
            con.execute(
                "UPDATE fraud_cases SET status=?,assigned_to=?,evidence=?,updated_at=? WHERE case_id=?",
                (status, analyst, json.dumps(evidence), utcnow(), case_id),
            )

    def set_street_mode(self, user_id: str, enabled: bool, limit: str = "200") -> None:
        with self.db.transaction() as con:
            con.execute(
                """INSERT INTO security_profiles(user_id,street_mode,street_limit_cents)
              VALUES(?,?,?) ON CONFLICT(user_id) DO UPDATE SET street_mode=excluded.street_mode,
              street_limit_cents=excluded.street_limit_cents""",
                (user_id, int(enabled), money_to_cents(limit)),
            )

    def set_duress_code(self, user_id: str, code: str) -> None:
        if not re.fullmatch(r"\d{6,12}", code):
            raise BankError("INVALID_DURESS", "Código de coerção inválido")
        salt = os.urandom(16)
        digest = base64.b64encode(salt + hashlib.pbkdf2_hmac("sha256", code.encode(), salt, 200000)).decode()
        with self.db.transaction() as con:
            con.execute(
                """INSERT INTO security_profiles(user_id,duress_hash) VALUES(?,?)
              ON CONFLICT(user_id) DO UPDATE SET duress_hash=excluded.duress_hash""",
                (user_id, digest),
            )

    def check_duress(self, user_id: str, code: str) -> bool:
        with self.db.transaction() as con:
            row = con.execute(
                "SELECT duress_hash FROM security_profiles WHERE user_id=?", (user_id,)
            ).fetchone()
            if not row or not row[0]:
                return False
            raw = base64.b64decode(row[0])
            valid = hmac.compare_digest(
                raw[16:], hashlib.pbkdf2_hmac("sha256", code.encode(), raw[:16], 200000)
            )
            if valid:
                con.execute("UPDATE security_profiles SET preventive_block=1 WHERE user_id=?", (user_id,))
        return valid


class KYCService:
    def __init__(self, db: BankDatabase, vault: VaultService):
        self.db, self.vault = db, vault
        AdvancedSchema(db)

    def create_customer(self, data: dict[str, Any]) -> str:
        document = re.sub(r"\D", "", str(data["document"]))
        dtype = "CPF" if len(document) == 11 else "CNPJ" if len(document) == 14 else ""
        if not dtype or not (validate_cpf(document) if dtype == "CPF" else validate_cnpj(document)):
            raise BankError("INVALID_DOCUMENT", "CPF/CNPJ inválido")
        if not validate_email(data["email"]) or not validate_phone(data["phone"]):
            raise BankError("INVALID_CONTACT", "E-mail ou telefone inválido")
        required = {
            "name",
            "document",
            "email",
            "phone",
            "nationality",
            "tax_residence",
            "occupation",
            "income_source",
            "address",
        }
        if missing := required - set(data):
            raise BankError("MISSING_KYC", "Campos ausentes: " + ",".join(sorted(missing)))
        customer_id, now = str(uuid.uuid4()), utcnow()
        pii = {
            **data,
            "name": sanitize_text(data["name"], 120),
            "address": " ".join(sanitize_text(data["address"], 300).upper().split()),
        }
        object_id = self.vault.encrypt("CUSTOMER_PII", json.dumps(pii, ensure_ascii=False), customer_id)
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO customers VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                (
                    customer_id,
                    hash_token(document),
                    dtype,
                    object_id,
                    "PENDING",
                    "UNASSESSED",
                    data.get("segment"),
                    json.dumps(data.get("tags", [])),
                    (datetime.now(UTC) + timedelta(days=365)).isoformat(),
                    now,
                    now,
                ),
            )
            review = str(uuid.uuid4())
            con.execute(
                "INSERT INTO kyc_reviews VALUES(?,?,?,?,?,?,?,?)",
                (
                    review,
                    customer_id,
                    "PENDING",
                    json.dumps({"document": False, "liveness": False}),
                    None,
                    None,
                    now,
                    now,
                ),
            )
        return customer_id

    def customer(self, customer_id: str) -> dict[str, Any]:
        with self.db.connect() as con:
            row = con.execute("SELECT * FROM customers WHERE customer_id=?", (customer_id,)).fetchone()
        if not row:
            raise BankError("CUSTOMER_NOT_FOUND", "Cliente não encontrado")
        result = dict(row)
        result["pii"] = json.loads(self.vault.decrypt(row["pii_object_id"]))
        return result

    def upload_document(self, customer_id: str, name: str, content: bytes) -> str:
        if not content or len(content) > 10 * 1024 * 1024:
            raise BankError("INVALID_UPLOAD", "Documento vazio ou maior que 10MB")
        object_id = self.vault.encrypt("KYC_DOCUMENT:" + sanitize_text(name, 80), content, customer_id)
        self.timeline(customer_id, "DOCUMENT_UPLOAD", name, None)
        return object_id

    def review(self, review_id: str, decision: str, reviewer: str, reason: str = "") -> None:
        if decision not in {"APPROVED", "REJECTED", "PENDING_INFO"}:
            raise BankError("INVALID_DECISION", "Decisão inválida")
        with self.db.transaction() as con:
            row = con.execute(
                "SELECT customer_id FROM kyc_reviews WHERE review_id=?", (review_id,)
            ).fetchone()
            if not row:
                raise BankError("REVIEW_NOT_FOUND", "Análise não encontrada")
            con.execute(
                "UPDATE kyc_reviews SET status=?,reason=?,reviewer=?,updated_at=? WHERE review_id=?",
                (decision, sanitize_text(reason), reviewer, utcnow(), review_id),
            )
            status = (
                "ACTIVE" if decision == "APPROVED" else "REJECTED" if decision == "REJECTED" else "PENDING"
            )
            con.execute(
                "UPDATE customers SET status=?,updated_at=? WHERE customer_id=?", (status, utcnow(), row[0])
            )

    def relate(self, source: str, target: str, relation: str, percentage: str | None = None) -> str:
        identifier = str(uuid.uuid4())
        if percentage is not None and not Decimal("0") <= Decimal(percentage) <= Decimal("100"):
            raise BankError("INVALID_PERCENTAGE", "Percentual inválido")
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO customer_relations VALUES(?,?,?,?,?,?)",
                (identifier, source, target, relation, percentage, None),
            )
        return identifier

    def consent(self, customer: str, purpose: str, version: str) -> str:
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO consents VALUES(?,?,?,?,?,?,?)",
                (identifier, customer, purpose, version, "GRANTED", utcnow(), None),
            )
        return identifier

    def revoke_consent(self, consent_id: str) -> None:
        with self.db.transaction() as con:
            con.execute(
                "UPDATE consents SET state='REVOKED',revoked_at=? WHERE consent_id=?", (utcnow(), consent_id)
            )

    def timeline(self, customer: str, kind: str, note: str, actor: str | None) -> str:
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO timeline VALUES(?,?,?,?,?,?)",
                (identifier, customer, kind, sanitize_text(note, 1000), actor, utcnow()),
            )
        return identifier

    def complaint(
        self, customer: str, subject: str, description: str, priority: str = "NORMAL", sla_hours: int = 48
    ) -> str:
        protocol = datetime.now(UTC).strftime("%Y%m%d%H%M%S") + secrets.token_hex(3).upper()
        now = utcnow()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO complaints VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    protocol,
                    customer,
                    sanitize_text(subject, 120),
                    sanitize_text(description, 2000),
                    "OPEN",
                    priority,
                    (datetime.now(UTC) + timedelta(hours=sla_hours)).isoformat(),
                    now,
                    now,
                ),
            )
        return protocol

    def simulated_cep(self, cep: str) -> dict[str, str]:
        digits = re.sub(r"\D", "", cep)
        if len(digits) != 8:
            raise BankError("INVALID_CEP", "CEP inválido")
        return {
            "cep": digits,
            "street": f"Logradouro simulado {digits[:5]}",
            "city": "Cidade Simulada",
            "state": "SP",
            "source": "SANDBOX",
        }

    def simulate_document_check(
        self, customer: str, document_object: str, liveness_score: Decimal | str
    ) -> dict[str, Any]:
        content = self.vault.decrypt(document_object)
        score = Decimal(str(liveness_score))
        valid = bool(content) and score >= Decimal("0.80")
        self.timeline(customer, "IDENTITY_CHECK", f"document={valid};liveness={score}", None)
        return {"document_valid": bool(content), "liveness_score": str(score), "approved": valid}


class AccountService:
    MAX_STATEMENT_ROWS = 5000
    PRODUCTS = {
        "JOINT",
        "MINOR",
        "UNIVERSITY",
        "BASIC",
        "PREPAID",
        "CHECKING",
        "SAVINGS",
        "SALARY",
        "BUSINESS",
        "SUBACCOUNT",
        "MULTICURRENCY",
    }

    def __init__(self, db: BankDatabase, ledger: LedgerService):
        self.db, self.ledger = db, ledger
        AdvancedSchema(db)

    def configure(
        self,
        account: str,
        product: str,
        owners: list[tuple[str, str]],
        alias: str = "",
        currency: str = "BRL",
        parent: str | None = None,
        joint_mode: str | None = None,
    ) -> None:
        if product not in self.PRODUCTS:
            raise BankError("INVALID_PRODUCT", "Produto inválido")
        if product == "JOINT" and len(owners) < 2:
            raise BankError("JOINT_OWNERS", "Conta conjunta exige dois titulares")
        if product == "MINOR" and not any(role == "GUARDIAN" for _, role in owners):
            raise BankError("GUARDIAN_REQUIRED", "Conta de menor exige responsável")
        with self.db.transaction() as con:
            con.execute(
                "INSERT OR REPLACE INTO account_profiles VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
                (
                    account,
                    sanitize_text(alias, 40),
                    product,
                    joint_mode,
                    None,
                    currency,
                    parent,
                    0,
                    0,
                    None,
                    None,
                    None,
                ),
            )
            for customer, role in owners:
                con.execute(
                    "INSERT OR REPLACE INTO account_owners VALUES(?,?,?,?)",
                    (account, customer, role, int(joint_mode == "ALL")),
                )
                con.execute(
                    "INSERT OR IGNORE INTO customer_products VALUES(?,?,?)", (customer, "ACCOUNT", account)
                )

    def package(self, name: str, fee: str, included: int, exemption: dict[str, Any]) -> str:
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO service_packages VALUES(?,?,?,?,?,1)",
                (identifier, sanitize_text(name), money_to_cents(fee), included, json.dumps(exemption)),
            )
        return identifier

    def set_limit(
        self,
        account: str,
        channel: str,
        operation: str,
        daily: str | None,
        weekly: str | None,
        monthly: str | None,
        effective_at: str | None = None,
    ) -> None:
        with self.db.transaction() as con:
            con.execute(
                "INSERT OR REPLACE INTO operation_limits VALUES(?,?,?,?,?,?,?,?)",
                (
                    account,
                    channel,
                    operation,
                    money_to_cents(daily) if daily else None,
                    money_to_cents(weekly) if weekly else None,
                    money_to_cents(monthly) if monthly else None,
                    effective_at or utcnow(),
                    "ACTIVE",
                ),
            )

    def block(self, account: str, reason: str, legal: str = "0", guarantee: str = "0") -> None:
        """Define (não acumula) o bloqueio judicial/garantia da conta.

        Somar o valor a cada chamada tornava a operação não idempotente: repetir
        o mesmo bloqueio congelava o dobro do saldo.
        """
        legal_c, guarantee_c = money_to_cents(legal), money_to_cents(guarantee)
        with self.db.transaction() as con:
            previous = con.execute(
                """SELECT legal_block_cents+guarantee_block_cents FROM account_profiles
              WHERE account_number=?""",
                (account,),
            ).fetchone()
            delta = legal_c + guarantee_c - (previous[0] if previous else 0)
            con.execute(
                """UPDATE account_profiles SET block_reason=?,legal_block_cents=?,
              guarantee_block_cents=? WHERE account_number=?""",
                (sanitize_text(reason), legal_c, guarantee_c, account),
            )
            con.execute(
                "UPDATE customer_accounts SET blocked_balance_cents=blocked_balance_cents+?,status='BLOCKED' WHERE account_number=?",
                (delta, account),
            )

    def statement(
        self,
        account: str,
        start: str,
        end: str,
        query: str | None = None,
        kind: str | None = None,
        state: str | None = None,
        limit: int = 500,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        """Extrato paginado.

        Sem teto, uma conta antiga devolvia o histórico inteiro em memória a
        cada chamada — e `export_ofx` a chamava sem filtro nenhum.
        """
        sql = """SELECT t.*,e.debit_cents,e.credit_cents,e.memo FROM ledger_transactions t
          JOIN ledger_entries e USING(transaction_id) WHERE e.customer_account=?
          AND t.accounting_date BETWEEN ? AND ?"""
        params: list[Any] = [account, start, end]
        if query:
            sql += " AND (t.description LIKE ? OR e.memo LIKE ?)"
            params += [f"%{query}%", f"%{query}%"]
        if kind:
            sql += " AND t.kind=?"
            params.append(kind)
        if state:
            sql += " AND t.state=?"
            params.append(state)
        sql += " ORDER BY t.accounting_date DESC, t.transaction_id LIMIT ? OFFSET ?"
        params += [max(1, min(self.MAX_STATEMENT_ROWS, limit)), max(0, offset)]
        with self.db.connect() as con:
            return [dict(row) for row in con.execute(sql, params)]

    def export_ofx(self, account: str, start: str, end: str) -> str:
        rows = self.statement(account, start, end)
        body = "".join(
            f"<STMTTRN><TRNTYPE>{escape(r['kind'])}<DTPOSTED>{r['accounting_date'].replace('-', '')}<TRNAMT>{(Decimal(r['credit_cents'] - r['debit_cents']) / 100):.2f}<FITID>{escape(r['transaction_id'])}<MEMO>{escape(r['description'])}</STMTTRN>"
            for r in rows
        )
        return f"OFXHEADER:100\n<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><BANKTRANLIST>{body}</BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>"

    def record_event(
        self, account: str, kind: str, amount: str = "0", payload: dict[str, Any] | None = None
    ) -> str:
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO account_events VALUES(?,?,?,?,?,?)",
                (identifier, account, kind, money_to_cents(amount), json.dumps(payload or {}), utcnow()),
            )
        return identifier

    def close(self, account: str, destination: str | None = None) -> str:
        balance = self.ledger.account(account)["ledger_balance_cents"]
        if balance and not destination:
            raise BankError("DESTINATION_REQUIRED", "Informe conta para transferir saldo")
        if balance:
            self.ledger.transfer(
                account,
                destination,
                cents_to_money(balance),
                f"closure:{account}:{uuid.uuid4()}",
                kind="ACCOUNT_CLOSURE",
                description="Transferência de encerramento",
            )
        protocol = "ENC" + datetime.now(UTC).strftime("%Y%m%d%H%M%S") + secrets.token_hex(2).upper()
        with self.db.transaction() as con:
            con.execute(
                "UPDATE account_profiles SET closure_state='CLOSED',closure_protocol=? WHERE account_number=?",
                (protocol, account),
            )
            con.execute(
                "UPDATE customer_accounts SET status='CLOSED',updated_at=? WHERE account_number=?",
                (utcnow(), account),
            )
        return protocol

    def charge_monthly_fee(self, account: str, reference: str, prorata_days: int = 30) -> str | None:
        with self.db.connect() as con:
            row = con.execute(
                """SELECT p.monthly_fee_cents,p.exemption_rule FROM account_profiles a
              JOIN service_packages p USING(package_id) WHERE a.account_number=? AND p.active=1""",
                (account,),
            ).fetchone()
        if not row:
            return None
        rule = json.loads(row["exemption_rule"])
        data = self.ledger.account(account)
        if rule.get("salary") and data["kind"] == "CS":
            return None
        value = max(0, int(row["monthly_fee_cents"] * min(max(prorata_days, 0), 30) / 30))
        return self.ledger.external_debit(
            account,
            value,
            f"fee:{account}:{reference}",
            "PACKAGE_FEE",
            f"Pacote {reference}",
            destination_account="FEE_REVENUE",
        )


class TransactionEngine:
    def __init__(self, db: BankDatabase, ledger: LedgerService, vault: VaultService):
        self.db, self.ledger, self.vault = db, ledger, vault
        AdvancedSchema(db)

    def create(
        self,
        kind: str,
        idempotency: str,
        description: str,
        gross: str,
        fee: str = "0",
        tax: str = "0",
        channel: str = "CLI",
        device: str = "",
        category: str = "",
        tags: Iterable[str] = (),
        attachment: bytes | None = None,
        location: tuple[str, str] | None = None,
        timeout_seconds: int = 300,
    ) -> str:
        gross_c, fee_c, tax_c = map(money_to_cents, (gross, fee, tax))
        net = gross_c - fee_c - tax_c
        if gross_c <= 0 or net < 0:
            raise AccountingError("INVALID_TOTALS", "Totais inválidos")
        transaction_id = str(uuid.uuid4())
        receipt = secrets.token_urlsafe(24)
        attachment_id = self.vault.encrypt("TRANSACTION_ATTACHMENT", attachment) if attachment else None
        now = utcnow()
        with self.db.transaction() as con:
            existing = con.execute(
                "SELECT transaction_id FROM ledger_transactions WHERE idempotency_key=?", (idempotency,)
            ).fetchone()
            if existing:
                return existing[0]
            con.execute(
                """INSERT INTO ledger_transactions(transaction_id,idempotency_key,kind,state,
              description,effective_at,accounting_date,metadata,created_at)
              VALUES(?,?,?,?,?,?,?,?,?)""",
                (
                    transaction_id,
                    idempotency,
                    kind,
                    "CREATED",
                    sanitize_text(description),
                    now,
                    now[:10],
                    "{}",
                    now,
                ),
            )
            con.execute(
                "INSERT INTO transaction_details VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (
                    transaction_id,
                    "CREATED",
                    None,
                    None,
                    0,
                    (datetime.now(UTC) + timedelta(seconds=timeout_seconds)).isoformat(),
                    category,
                    json.dumps(list(tags)),
                    attachment_id,
                    location[0] if location else None,
                    location[1] if location else None,
                    channel,
                    device,
                    gross_c,
                    fee_c,
                    tax_c,
                    net,
                    receipt,
                    None,
                    now,
                ),
            )
        return transaction_id

    def transition(
        self,
        transaction_id: str,
        target: str,
        code: str | None = None,
        reason: str | None = None,
        admin_reason: str | None = None,
    ) -> None:
        with self.db.transaction() as con:
            row = con.execute(
                "SELECT engine_state,timeout_at FROM transaction_details WHERE transaction_id=?",
                (transaction_id,),
            ).fetchone()
            if not row:
                raise BankError("TRANSACTION_NOT_FOUND", "Transação não encontrada")
            current = row["engine_state"]
            if current not in TRANSITIONS:
                raise BankError("UNKNOWN_STATE", f"Estado desconhecido: {current}")
            if target not in TRANSITIONS[current]:
                raise BankError("INVALID_TRANSITION", f"{current}->{target}")
            if target == "PROCESSING" and datetime.fromisoformat(row["timeout_at"]) < datetime.now(UTC):
                target, code, reason = "FAILED", "TIMEOUT", "Tempo de processamento excedido"
            if target == "CANCELLED" and current == "SETTLED":
                raise BankError("CANNOT_CANCEL", "Liquidação exige estorno")
            con.execute(
                """UPDATE transaction_details SET engine_state=?,failure_code=?,
              failure_reason=?,attempts=attempts+CASE WHEN ?='PROCESSING' THEN 1 ELSE 0 END,
              administrative_reason=?,updated_at=? WHERE transaction_id=?""",
                (
                    target,
                    code,
                    sanitize_text(reason or ""),
                    target,
                    sanitize_text(admin_reason or ""),
                    utcnow(),
                    transaction_id,
                ),
            )
            mapped = {
                "SETTLED": "SETTLED",
                "FAILED": "FAILED",
                "CANCELLED": "CANCELLED",
                "REVERSED": "REVERSED",
                "PARTIALLY_REVERSED": "PARTIALLY_REVERSED",
            }.get(target, target)
            con.execute(
                "UPDATE ledger_transactions SET state=? WHERE transaction_id=?", (mapped, transaction_id)
            )

    def receipt(self, code: str) -> dict[str, Any]:
        with self.db.connect() as con:
            row = con.execute(
                """SELECT t.transaction_id,t.kind,t.description,t.accounting_date,
              d.engine_state,d.gross_cents,d.fee_cents,d.tax_cents,d.net_cents
              FROM transaction_details d JOIN ledger_transactions t USING(transaction_id)
              WHERE d.receipt_code=?""",
                (code,),
            ).fetchone()
        if not row:
            raise BankError("RECEIPT_NOT_FOUND", "Comprovante inválido")
        return dict(row)

    def batch(self, owner: str, items: list[dict[str, Any]], approval_required: bool = False) -> str:
        batch_id = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO transaction_batches VALUES(?,?,?,?,?,?)",
                (batch_id, owner, "PENDING", int(approval_required), None, utcnow()),
            )
            for index, item in enumerate(items, 1):
                con.execute(
                    "INSERT INTO batch_items VALUES(?,?,?,?,?,?)",
                    (batch_id, index, json.dumps(item), "PENDING", None, None),
                )
        return batch_id

    def execute_batch(self, batch_id: str, approved_by: str | None = None) -> dict[str, int]:
        with self.db.connect() as con:
            batch = con.execute("SELECT * FROM transaction_batches WHERE batch_id=?", (batch_id,)).fetchone()
            items = con.execute(
                "SELECT * FROM batch_items WHERE batch_id=? ORDER BY item_no", (batch_id,)
            ).fetchall()
        if not batch:
            raise BankError("BATCH_NOT_FOUND", "Lote não encontrado")
        if batch["approval_required"]:
            if not approved_by:
                raise AuthorizationError("BATCH_APPROVAL_REQUIRED", "Lote exige aprovação")
            if approved_by == batch["owner_id"]:
                raise AuthorizationError("FOUR_EYES", "Solicitante não pode aprovar o próprio lote")
        if batch["state"] == "SETTLED":
            raise BankError("BATCH_ALREADY_EXECUTED", "Lote já executado")
        ok = failed = 0
        for row in items:
            payload = json.loads(row["payload"])
            try:
                tx = self.ledger.transfer(
                    payload["origin"],
                    payload["destination"],
                    payload["amount"],
                    f"batch:{batch_id}:{row['item_no']}",
                    kind=payload.get("kind", "BATCH_TRANSFER"),
                )
                with self.db.transaction() as con:
                    con.execute(
                        "UPDATE batch_items SET state='SETTLED',transaction_id=? WHERE batch_id=? AND item_no=?",
                        (tx, batch_id, row["item_no"]),
                    )
                ok += 1
            except Exception as exc:
                with self.db.transaction() as con:
                    con.execute(
                        "UPDATE batch_items SET state='FAILED',error=? WHERE batch_id=? AND item_no=?",
                        (str(exc)[:300], batch_id, row["item_no"]),
                    )
                failed += 1
        with self.db.transaction() as con:
            con.execute(
                "UPDATE transaction_batches SET state=?,approved_by=? WHERE batch_id=?",
                ("SETTLED" if not failed else "PARTIAL", approved_by, batch_id),
            )
        return {"settled": ok, "failed": failed}

    def holidays(self, day: str, name: str) -> None:
        date.fromisoformat(day)
        with self.db.transaction() as con:
            con.execute("INSERT OR REPLACE INTO holidays VALUES(?,?)", (day, sanitize_text(name)))


class AdvancedBanking:
    def __init__(
        self,
        db: BankDatabase,
        ledger: LedgerService,
        master_key: bytes | None = None,
        key_provider: KeyProvider | None = None,
    ):
        self.vault = VaultService(db, master_key, key_provider)
        self.fraud = FraudService(db)
        self.kyc = KYCService(db, self.vault)
        self.accounts = AccountService(db, ledger)
        self.transactions = TransactionEngine(db, ledger, self.vault)
