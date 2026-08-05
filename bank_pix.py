"""Implementação PIX completa para o sandbox Banco COBOL."""

from __future__ import annotations

import hashlib
import hmac
import json
import re
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Any

from bank_observability import LOGGER
from bank_core import (
    AccountingError,
    AuthorizationError,
    BankDatabase,
    BankError,
    LedgerService,
    ModuleIntegrationService,
    SecurityService,
    cents_to_money,
    hash_token,
    money_to_cents,
    utcnow,
)


def crc16_ccitt(text: str) -> str:
    crc = 0xFFFF
    for byte in text.encode("utf-8"):
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return f"{crc:04X}"


def tlv(identifier: str, value: str) -> str:
    encoded = value.encode("utf-8")
    if len(encoded) > 99:
        raise BankError("EMV_FIELD_TOO_LONG", f"Campo EMV {identifier} excede 99 bytes")
    return f"{identifier}{len(encoded):02d}{value}"


def parse_tlv(payload: str) -> dict[str, str]:
    result, index = {}, 0
    while index < len(payload):
        if index + 4 > len(payload) or not payload[index : index + 4].isdigit():
            raise BankError("INVALID_EMV", "Payload EMV truncado")
        identifier, size = payload[index : index + 2], int(payload[index + 2 : index + 4])
        index += 4
        value = payload[index : index + size]
        if len(value.encode("utf-8")) != size:
            raise BankError("INVALID_EMV", "Tamanho EMV inválido")
        result[identifier] = value
        index += len(value)
    return result


class PixService:
    MAX_WEBHOOK_ATTEMPTS = 5
    KEY_TYPES = {"CPF", "CNPJ", "EMAIL", "PHONE", "EVP"}

    def __init__(
        self,
        db: BankDatabase,
        ledger: LedgerService,
        scheduler: ModuleIntegrationService | None = None,
        security: SecurityService | None = None,
        vault: Any | None = None,
    ):
        self.db, self.ledger, self.scheduler = db, ledger, scheduler
        self.security = security
        self.vault = vault
        with db.transaction() as con:
            con.executescript(
                """
                CREATE TABLE IF NOT EXISTS pix_keys(
                  key_id TEXT PRIMARY KEY,key_hash TEXT UNIQUE NOT NULL,key_value TEXT NOT NULL,
                  key_type TEXT NOT NULL,account_number TEXT NOT NULL,owner_name TEXT NOT NULL,
                  institution TEXT NOT NULL,state TEXT NOT NULL,claim_state TEXT,
                  portability_state TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS pix_charges(
                  txid TEXT PRIMARY KEY,key_id TEXT NOT NULL,account_number TEXT NOT NULL,
                  amount_cents INTEGER,due_at TEXT,description TEXT NOT NULL,
                  interest_percent TEXT NOT NULL,mult_percent TEXT NOT NULL,
                  discount_percent TEXT NOT NULL,state TEXT NOT NULL,dynamic INTEGER NOT NULL,
                  payer_name TEXT,payer_document TEXT,paid_transaction_id TEXT,
                  created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS pix_transfers(
                  pix_id TEXT PRIMARY KEY,transaction_id TEXT UNIQUE NOT NULL,
                  origin_account TEXT NOT NULL,destination_account TEXT NOT NULL,
                  key_id TEXT,amount_cents INTEGER NOT NULL,description TEXT NOT NULL,
                  channel TEXT NOT NULL,state TEXT NOT NULL,e2e_id TEXT UNIQUE NOT NULL,
                  created_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS pix_refunds(
                  refund_id TEXT PRIMARY KEY,pix_id TEXT NOT NULL,transaction_id TEXT,
                  amount_cents INTEGER NOT NULL,reason TEXT NOT NULL,state TEXT NOT NULL,
                  requested_by TEXT NOT NULL,created_at TEXT NOT NULL,processed_at TEXT);
                CREATE TABLE IF NOT EXISTS pix_limits(
                  account_number TEXT PRIMARY KEY,day_limit_cents INTEGER NOT NULL,
                  night_limit_cents INTEGER NOT NULL,night_start INTEGER NOT NULL,
                  night_end INTEGER NOT NULL,proximity_limit_cents INTEGER NOT NULL,
                  effective_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS pix_beneficiary_limits(
                  account_number TEXT NOT NULL,key_hash TEXT NOT NULL,limit_cents INTEGER NOT NULL,
                  trusted INTEGER NOT NULL DEFAULT 0,alias TEXT,PRIMARY KEY(account_number,key_hash));
                CREATE TABLE IF NOT EXISTS pix_caution_blocks(
                  block_id TEXT PRIMARY KEY,pix_id TEXT NOT NULL,amount_cents INTEGER NOT NULL,
                  reason TEXT NOT NULL,state TEXT NOT NULL,expires_at TEXT NOT NULL,
                  created_at TEXT NOT NULL,released_at TEXT);
                CREATE TABLE IF NOT EXISTS pix_disputes(
                  dispute_id TEXT PRIMARY KEY,pix_id TEXT NOT NULL,reason TEXT NOT NULL,
                  evidence TEXT NOT NULL,state TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS pix_webhooks(
                  webhook_id TEXT PRIMARY KEY,url TEXT NOT NULL,secret TEXT NOT NULL,
                  event TEXT NOT NULL,payload TEXT NOT NULL,signature TEXT NOT NULL,
                  state TEXT NOT NULL,attempts INTEGER NOT NULL,created_at TEXT NOT NULL,sent_at TEXT);
                CREATE TABLE IF NOT EXISTS pix_reconciliation(
                  reconciliation_id TEXT PRIMARY KEY,txid TEXT NOT NULL,pix_id TEXT,
                  expected_cents INTEGER NOT NULL,received_cents INTEGER NOT NULL,
                  state TEXT NOT NULL,created_at TEXT NOT NULL);
                CREATE INDEX IF NOT EXISTS idx_pix_keys_account ON pix_keys(account_number,state);
                CREATE INDEX IF NOT EXISTS idx_pix_refunds_pix ON pix_refunds(pix_id,state);
                """
            )

    @staticmethod
    def normalize_key(key_type: str, value: str | None = None) -> str:
        key_type = key_type.upper()
        if key_type == "EVP":
            return (
                str(uuid.UUID(bytes=secrets.token_bytes(16), version=4))
                if value is None
                else str(uuid.UUID(value))
            )
        if value is None:
            raise BankError("PIX_KEY_REQUIRED", "Chave obrigatória")
        if key_type in {"CPF", "CNPJ", "PHONE"}:
            value = re.sub(r"\D", "", value)
        elif key_type == "EMAIL":
            value = value.strip().casefold()
        if key_type == "CPF" and len(value) != 11:
            raise BankError("INVALID_PIX_KEY", "CPF inválido")
        if key_type == "CNPJ" and len(value) != 14:
            raise BankError("INVALID_PIX_KEY", "CNPJ inválido")
        if key_type == "PHONE" and len(value) not in {10, 11, 12, 13}:
            raise BankError("INVALID_PIX_KEY", "Telefone inválido")
        if key_type == "EMAIL" and not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", value):
            raise BankError("INVALID_PIX_KEY", "E-mail inválido")
        return value

    VAULT_PREFIX = "vault:"

    def _store_key_value(self, normalized: str) -> str:
        """Chave PIX é PII (CPF, e-mail, telefone). Com cofre, só o ciframento
        vai para a tabela; a busca continua pelo `key_hash`."""
        if not self.vault:
            return normalized
        return self.VAULT_PREFIX + self.vault.encrypt("PIX_KEY", normalized)

    def _read_key_value(self, stored: str | None) -> str | None:
        if stored is None or not stored.startswith(self.VAULT_PREFIX):
            return stored
        if not self.vault:
            raise BankError("VAULT_UNAVAILABLE", "Chave PIX cifrada exige cofre configurado")
        return self.vault.decrypt(stored[len(self.VAULT_PREFIX) :]).decode("utf-8")

    def register_key(
        self,
        account: str,
        key_type: str,
        value: str | None,
        owner_name: str,
        institution: str = "Banco COBOL S/A",
    ) -> dict[str, str]:
        key_type = key_type.upper()
        if key_type not in self.KEY_TYPES:
            raise BankError("INVALID_PIX_KEY_TYPE", "Tipo de chave inválido")
        normalized = self.normalize_key(key_type, value)
        key_id, now = str(uuid.uuid4()), utcnow()
        stored_value = self._store_key_value(normalized)
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO pix_keys VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
                (
                    key_id,
                    hash_token(normalized),
                    stored_value,
                    key_type,
                    account,
                    owner_name,
                    institution,
                    "ACTIVE",
                    None,
                    None,
                    now,
                    now,
                ),
            )
        return {"key_id": key_id, "key": normalized, "type": key_type}

    def list_keys(self, account: str, include_inactive: bool = False) -> list[dict[str, Any]]:
        sql = "SELECT key_id,key_value,key_type,owner_name,institution,state,claim_state,portability_state,created_at FROM pix_keys WHERE account_number=?"
        if not include_inactive:
            sql += " AND state='ACTIVE'"
        with self.db.connect() as con:
            rows = [dict(row) for row in con.execute(sql, (account,))]
        for row in rows:
            row["key_value"] = self._read_key_value(row["key_value"])
        return rows

    def delete_key(self, key_id: str, account: str) -> None:
        with self.db.transaction() as con:
            changed = con.execute(
                "UPDATE pix_keys SET state='DELETED',updated_at=? WHERE key_id=? AND account_number=? AND state='ACTIVE'",
                (utcnow(), key_id, account),
            ).rowcount
        if not changed:
            raise BankError("PIX_KEY_NOT_FOUND", "Chave ativa não encontrada")

    def replace_key(
        self, key_id: str, account: str, key_type: str, value: str | None, owner_name: str
    ) -> dict[str, str]:
        new = self.register_key(account, key_type, value, owner_name)
        try:
            self.delete_key(key_id, account)
        except Exception:
            self.delete_key(new["key_id"], account)
            raise
        return new

    def portability(
        self, key: str, destination_account: str, approve: bool = False, approved_by: str | None = None
    ) -> str:
        """Move a chave de conta. A aprovação exige um ator com ACCOUNT_MANAGE.

        Sem essa checagem qualquer chamador que conheça o valor da chave
        redireciona todos os PIX futuros para a própria conta.
        """
        if approve:
            self._require_key_authority(approved_by, "portabilidade")
        with self.db.transaction() as con:
            row = con.execute(
                "SELECT * FROM pix_keys WHERE key_hash=? AND state='ACTIVE'", (hash_token(key),)
            ).fetchone()
            if not row:
                raise BankError("PIX_KEY_NOT_FOUND", "Chave não encontrada")
            state = "APPROVED" if approve else "REQUESTED"
            con.execute(
                "UPDATE pix_keys SET portability_state=?,account_number=CASE WHEN ? THEN ? ELSE account_number END,updated_at=? WHERE key_id=?",
                (state, int(approve), destination_account, utcnow(), row["key_id"]),
            )
        return state

    def claim_ownership(
        self, key: str, claimant_account: str, decision: str = "REQUESTED", approved_by: str | None = None
    ) -> str:
        if decision not in {"REQUESTED", "APPROVED", "REJECTED"}:
            raise BankError("INVALID_CLAIM", "Decisão inválida")
        if decision == "APPROVED":
            self._require_key_authority(approved_by, "reivindicação")
        with self.db.transaction() as con:
            row = con.execute("SELECT * FROM pix_keys WHERE key_hash=?", (hash_token(key),)).fetchone()
            if not row:
                raise BankError("PIX_KEY_NOT_FOUND", "Chave não encontrada")
            con.execute(
                "UPDATE pix_keys SET claim_state=?,account_number=CASE WHEN ?='APPROVED' THEN ? ELSE account_number END,updated_at=? WHERE key_id=?",
                (decision, decision, claimant_account, utcnow(), row["key_id"]),
            )
        return decision

    def _require_debit_authority(self, actor_id: str | None, account: str) -> None:
        """Exige prova de titularidade da conta debitada.

        Quando `security` está configurado o ator passa a ser obrigatório: aceitar
        `None` reabriria a falha de "número da conta como parâmetro confiável".
        Sem `security` (sandbox/testes) mantém-se o comportamento anterior.
        """
        if not self.security:
            return
        if not actor_id:
            raise AuthorizationError("ACTOR_REQUIRED", "Operação de débito exige usuário autenticado")
        self.security.require_account_access(actor_id, account, "TRANSACT")

    def _require_key_authority(self, actor_id: str | None, operation: str) -> None:
        if not self.security:
            raise AuthorizationError(
                "SECURITY_UNAVAILABLE", f"Aprovação de {operation} exige serviço de segurança configurado"
            )
        if not actor_id:
            raise AuthorizationError("APPROVER_REQUIRED", f"Informe o aprovador da {operation}")
        self.security.require_permission(actor_id, "ACCOUNT_MANAGE")

    def resolve_key(self, key: str) -> dict[str, Any]:
        with self.db.connect() as con:
            row = con.execute(
                """SELECT key_id,key_type,account_number,owner_name,institution,state
              FROM pix_keys WHERE key_hash=?""",
                (hash_token(key),),
            ).fetchone()
        if not row or row["state"] != "ACTIVE":
            raise BankError("PIX_KEY_NOT_FOUND", "Chave PIX inválida")
        return dict(row)

    def configure_limits(
        self,
        account: str,
        day: str,
        night: str,
        night_start: int = 22,
        night_end: int = 6,
        proximity: str = "200",
    ) -> None:
        if not 0 <= night_start <= 23 or not 0 <= night_end <= 23:
            raise BankError("INVALID_NIGHT_PERIOD", "Período inválido")
        with self.db.transaction() as con:
            con.execute(
                "INSERT OR REPLACE INTO pix_limits VALUES(?,?,?,?,?,?,?)",
                (
                    account,
                    money_to_cents(day),
                    money_to_cents(night),
                    night_start,
                    night_end,
                    money_to_cents(proximity),
                    utcnow(),
                ),
            )

    def trust_contact(self, account: str, key: str, alias: str, limit: str) -> None:
        self.resolve_key(key)
        with self.db.transaction() as con:
            con.execute(
                "INSERT OR REPLACE INTO pix_beneficiary_limits VALUES(?,?,?,?,?)",
                (account, hash_token(key), money_to_cents(limit), 1, alias),
            )

    DEFAULT_DAY_LIMIT_CENTS = 500_000
    DEFAULT_NIGHT_LIMIT_CENTS = 100_000
    DEFAULT_NIGHT_START = 22
    DEFAULT_NIGHT_END = 6
    DEFAULT_PROXIMITY_LIMIT_CENTS = 20_000

    def _check_limits(self, account: str, key: str, amount: int, channel: str) -> None:
        now = datetime.now(UTC)
        with self.db.connect() as con:
            limits = con.execute("SELECT * FROM pix_limits WHERE account_number=?", (account,)).fetchone()
            beneficiary = con.execute(
                "SELECT * FROM pix_beneficiary_limits WHERE account_number=? AND key_hash=?",
                (account, hash_token(key)),
            ).fetchone()
            spent = con.execute(
                """SELECT COALESCE(SUM(amount_cents),0) FROM pix_transfers
              WHERE origin_account=? AND state='SETTLED' AND created_at>=?""",
                (account, now.date().isoformat()),
            ).fetchone()[0]
        night_start = limits["night_start"] if limits else self.DEFAULT_NIGHT_START
        night_end = limits["night_end"] if limits else self.DEFAULT_NIGHT_END
        night = now.hour >= night_start or now.hour < night_end
        if limits:
            ceiling = limits["night_limit_cents"] if night else limits["day_limit_cents"]
            proximity_ceiling = limits["proximity_limit_cents"]
        else:
            ceiling = self.DEFAULT_NIGHT_LIMIT_CENTS if night else self.DEFAULT_DAY_LIMIT_CENTS
            proximity_ceiling = self.DEFAULT_PROXIMITY_LIMIT_CENTS
        if channel == "PROXIMITY":
            ceiling = min(ceiling, proximity_ceiling)
        if beneficiary:
            ceiling = min(ceiling, beneficiary["limit_cents"])
        if amount > ceiling or spent + amount > ceiling:
            raise AuthorizationError("PIX_LIMIT_EXCEEDED", "Limite PIX excedido")

    def transfer(
        self,
        origin: str,
        key: str,
        amount: str,
        idempotency: str,
        description: str = "",
        channel: str = "MOBILE",
        confirmed: bool = False,
        actor_id: str | None = None,
    ) -> dict[str, Any]:
        receiver = self.resolve_key(key)
        if not confirmed:
            return {
                "confirmation_required": True,
                "receiver_name": receiver["owner_name"],
                "institution": receiver["institution"],
                "amount": str(cents_to_money(money_to_cents(amount))),
            }
        self._require_debit_authority(actor_id, origin)
        value = money_to_cents(amount)
        self._check_limits(origin, key, value, channel)
        transaction = self.ledger.transfer(
            origin,
            receiver["account_number"],
            value,
            idempotency,
            kind="PIX",
            description=description or "PIX",
        )
        pix_id, e2e = (
            str(uuid.uuid4()),
            "E" + datetime.now(UTC).strftime("%Y%m%d") + secrets.token_hex(12).upper(),
        )
        with self.db.transaction() as con:
            existing = con.execute(
                "SELECT * FROM pix_transfers WHERE transaction_id=?", (transaction,)
            ).fetchone()
            if existing:
                return self.receipt(existing["pix_id"])
            con.execute(
                "INSERT INTO pix_transfers VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                (
                    pix_id,
                    transaction,
                    origin,
                    receiver["account_number"],
                    receiver["key_id"],
                    value,
                    description,
                    channel,
                    "SETTLED",
                    e2e,
                    utcnow(),
                ),
            )
        self.queue_webhook("PIX_CONFIRMED", {"pix_id": pix_id, "e2e_id": e2e, "amount_cents": value})
        return self.receipt(pix_id)

    def receipt(self, pix_id: str) -> dict[str, Any]:
        with self.db.connect() as con:
            row = con.execute(
                """SELECT p.*,k.owner_name,k.institution,k.key_value
              FROM pix_transfers p LEFT JOIN pix_keys k USING(key_id) WHERE pix_id=?""",
                (pix_id,),
            ).fetchone()
            refunds = con.execute(
                "SELECT COALESCE(SUM(amount_cents),0) FROM pix_refunds WHERE pix_id=? AND state='SETTLED'",
                (pix_id,),
            ).fetchone()[0]
        if not row:
            raise BankError("PIX_NOT_FOUND", "PIX não encontrado")
        result = dict(row)
        result["key_value"] = self._read_key_value(row["key_value"])
        result["amount"] = str(cents_to_money(row["amount_cents"]))
        result["refunded_amount"] = str(cents_to_money(refunds))
        return result

    def refund(
        self, pix_id: str, amount: str | None, reason: str, requested_by: str, idempotency: str | None = None
    ) -> str:
        """Devolve um PIX. `idempotency` distingue devoluções parciais legítimas
        de reenvios da mesma devolução; sem ela cada retentativa devolvia de novo.
        """
        refund_id = str(uuid.uuid4())
        with self.db.transaction() as con:
            row = con.execute(
                "SELECT amount_cents,origin_account,destination_account FROM pix_transfers WHERE pix_id=?",
                (pix_id,),
            ).fetchone()
            if not row:
                raise BankError("PIX_NOT_FOUND", "PIX não encontrado")
            self._require_debit_authority(requested_by, row["destination_account"])
            refunded = con.execute(
                """SELECT COALESCE(SUM(amount_cents),0) FROM pix_refunds
              WHERE pix_id=? AND state IN ('SETTLED','RESERVED')""",
                (pix_id,),
            ).fetchone()[0]
            value = row["amount_cents"] - refunded if amount is None else money_to_cents(amount)
            if value <= 0 or value + refunded > row["amount_cents"]:
                raise AccountingError("INVALID_REFUND", "Valor de devolução inválido")
            con.execute(
                "INSERT INTO pix_refunds VALUES(?,?,?,?,?,?,?,?,?)",
                (refund_id, pix_id, None, value, reason, "RESERVED", requested_by, utcnow(), None),
            )
        try:
            transaction = self.ledger.transfer(
                row["destination_account"],
                row["origin_account"],
                value,
                f"pix-refund:{pix_id}:{idempotency or refund_id}",
                kind="PIX_REFUND",
                description=reason,
            )
        except Exception:
            with self.db.transaction() as con:
                con.execute("UPDATE pix_refunds SET state='FAILED' WHERE refund_id=?", (refund_id,))
            raise
        with self.db.transaction() as con:
            con.execute(
                "UPDATE pix_refunds SET transaction_id=?,state='SETTLED',processed_at=? WHERE refund_id=?",
                (transaction, utcnow(), refund_id),
            )
        self.queue_webhook("PIX_REFUNDED", {"pix_id": pix_id, "refund_id": refund_id, "amount_cents": value})
        return refund_id

    def refund_history(self, pix_id: str) -> list[dict[str, Any]]:
        with self.db.connect() as con:
            return [
                dict(row)
                for row in con.execute(
                    "SELECT * FROM pix_refunds WHERE pix_id=? ORDER BY created_at", (pix_id,)
                )
            ]

    def request_refund(self, pix_id: str, amount: str, reason: str, user: str) -> str:
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO pix_refunds VALUES(?,?,?,?,?,?,?,?,?)",
                (identifier, pix_id, None, money_to_cents(amount), reason, "REQUESTED", user, utcnow(), None),
            )
        return identifier

    def dispute(self, pix_id: str, reason: str, evidence: dict[str, Any]) -> str:
        identifier, now = str(uuid.uuid4()), utcnow()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO pix_disputes VALUES(?,?,?,?,?,?,?)",
                (identifier, pix_id, reason, json.dumps(evidence), "OPEN", now, now),
            )
        return identifier

    def caution_block(self, pix_id: str, amount: str, reason: str, hours: int = 72) -> str:
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO pix_caution_blocks VALUES(?,?,?,?,?,?,?,?)",
                (
                    identifier,
                    pix_id,
                    money_to_cents(amount),
                    reason,
                    "ACTIVE",
                    (datetime.now(UTC) + timedelta(hours=hours)).isoformat(),
                    utcnow(),
                    None,
                ),
            )
        return identifier

    def create_charge(
        self,
        key_id: str,
        description: str,
        amount: str | None = None,
        due_at: str | None = None,
        interest: str = "0",
        mult: str = "0",
        discount: str = "0",
        dynamic: bool = True,
    ) -> dict[str, str]:
        with self.db.connect() as con:
            key = con.execute(
                "SELECT * FROM pix_keys WHERE key_id=? AND state='ACTIVE'", (key_id,)
            ).fetchone()
        if not key:
            raise BankError("PIX_KEY_NOT_FOUND", "Chave não encontrada")
        txid = secrets.token_urlsafe(20)[:25]
        now = utcnow()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO pix_charges VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (
                    txid,
                    key_id,
                    key["account_number"],
                    money_to_cents(amount) if amount else None,
                    due_at,
                    description,
                    str(interest),
                    str(mult),
                    str(discount),
                    "ACTIVE",
                    int(dynamic),
                    None,
                    None,
                    None,
                    now,
                    now,
                ),
            )
        return {
            "txid": txid,
            "payload": self.emv_payload(
                self._read_key_value(key["key_value"]), key["owner_name"], txid, description, amount, dynamic
            ),
        }

    def emv_payload(
        self,
        key: str,
        name: str,
        txid: str,
        description: str = "",
        amount: str | None = None,
        dynamic: bool = False,
        city: str = "SAO PAULO",
    ) -> str:
        gui = tlv("00", "BR.GOV.BCB.PIX")
        merchant = gui + tlv("01", key)
        if description:
            merchant += tlv("02", description[:72])
        payload = tlv("00", "01") + tlv("01", "12" if dynamic else "11") + tlv("26", merchant)
        payload += tlv("52", "0000") + tlv("53", "986")
        if amount is not None:
            payload += tlv("54", f"{Decimal(str(amount).replace(',', '.')):.2f}")
        payload += tlv("58", "BR") + tlv("59", name[:25].upper()) + tlv("60", city[:15].upper())
        payload += tlv("62", tlv("05", txid or "***")) + "6304"
        return payload + crc16_ccitt(payload)

    def validate_emv(self, payload: str) -> dict[str, str]:
        if len(payload) < 8 or payload[-8:-4] != "6304" or crc16_ccitt(payload[:-4]) != payload[-4:]:
            raise BankError("INVALID_EMV_CRC", "CRC PIX inválido")
        fields = parse_tlv(payload[:-8])
        merchant = parse_tlv(fields["26"])
        additional = parse_tlv(fields["62"])
        self.resolve_key(merchant["01"])
        return {**fields, "pix_key": merchant["01"], "txid": additional["05"]}

    def pay_charge(
        self,
        txid: str,
        origin: str,
        amount: str,
        payer_name: str,
        payer_document: str,
        actor_id: str | None = None,
    ) -> dict[str, Any]:
        with self.db.connect() as con:
            charge = con.execute(
                "SELECT c.*,k.key_value FROM pix_charges c JOIN pix_keys k USING(key_id) WHERE txid=?",
                (txid,),
            ).fetchone()
        if not charge or charge["state"] != "ACTIVE":
            raise BankError("CHARGE_NOT_ACTIVE", "Cobrança indisponível")
        base = charge["amount_cents"] if charge["amount_cents"] is not None else money_to_cents(amount)
        value = base if charge["amount_cents"] is not None else money_to_cents(amount)
        if charge["amount_cents"] is not None and money_to_cents(amount) != base:
            raise AccountingError("CHARGE_AMOUNT_MISMATCH", "Cobrança possui valor fixo")
        if charge["due_at"] and datetime.fromisoformat(charge["due_at"]) < datetime.now(UTC):
            value += int(base * Decimal(charge["mult_percent"]) / 100) + int(
                base * Decimal(charge["interest_percent"]) / 100
            )
        value -= int(base * Decimal(charge["discount_percent"]) / 100)
        result = self.transfer(
            origin,
            self._read_key_value(charge["key_value"]),
            str(cents_to_money(value)),
            f"charge:{txid}",
            charge["description"],
            confirmed=True,
            actor_id=actor_id,
        )
        with self.db.transaction() as con:
            con.execute(
                """UPDATE pix_charges SET state='PAID',payer_name=?,
          payer_document=?,paid_transaction_id=?,updated_at=? WHERE txid=?""",
                (payer_name, payer_document, result["transaction_id"], utcnow(), txid),
            )
        self.reconcile_charge(txid, result["pix_id"], value)
        return result

    def schedule_pix(
        self,
        origin: str,
        key: str,
        amount: str,
        when: str,
        recurrence: str = "ONCE",
        end_at: str | None = None,
        actor_id: str | None = None,
    ) -> str:
        if not self.scheduler:
            raise BankError("SCHEDULER_UNAVAILABLE", "Agendador indisponível")
        self._require_debit_authority(actor_id, origin)
        return self.scheduler.schedule(
            "PIX",
            {
                "module": "BANKPIX",
                "account_number": origin,
                "amount": amount,
                "actor_id": actor_id,
                "details": {"key": key},
            },
            when,
            recurrence=recurrence,
            end_at=end_at,
        )

    def run_scheduled(self, at: str | None = None) -> dict[str, int]:
        at = at or utcnow()
        processed = failed = 0
        with self.db.connect() as con:
            jobs = con.execute(
                """SELECT * FROM scheduled_jobs WHERE kind='PIX'
              AND state='ACTIVE' AND next_run_at<=? ORDER BY next_run_at""",
                (at,),
            ).fetchall()
        for job in jobs:
            payload = json.loads(job["payload"])
            details = payload["details"]
            try:
                self.transfer(
                    payload["account_number"],
                    details["key"],
                    payload["amount"],
                    f"{job['idempotency_prefix']}:{job['next_run_at']}",
                    "PIX agendado",
                    confirmed=True,
                    actor_id=payload.get("actor_id"),
                )
                next_run = ModuleIntegrationService._next_run(
                    job["next_run_at"], job["recurrence"], job["anchor_day"]
                )
                state = (
                    "COMPLETED"
                    if job["recurrence"] == "ONCE" or (job["end_at"] and next_run > job["end_at"])
                    else "ACTIVE"
                )
                with self.db.transaction() as con:
                    con.execute(
                        "UPDATE scheduled_jobs SET state=?,next_run_at=?,updated_at=? WHERE job_id=?",
                        (state, next_run, utcnow(), job["job_id"]),
                    )
                processed += 1
            except Exception as exc:
                with self.db.transaction() as con:
                    con.execute(
                        """UPDATE scheduled_jobs SET attempts=attempts+1,last_error=?,
                      state=CASE WHEN attempts+1>=5 THEN 'FAILED' ELSE 'ACTIVE' END,
                      updated_at=? WHERE job_id=?""",
                        (str(exc)[:500], utcnow(), job["job_id"]),
                    )
                failed += 1
        return {"processed": processed, "failed": failed}

    def proximity(
        self,
        origin: str,
        key: str,
        amount: str,
        device_token: str,
        confirmed: bool,
        idempotency: str | None = None,
        actor_id: str | None = None,
    ) -> dict[str, Any]:
        if not device_token.startswith("nfc_"):
            raise AuthorizationError("INVALID_DEVICE_TOKEN", "Token de aproximação inválido")
        return self.transfer(
            origin,
            key,
            amount,
            f"proximity:{device_token}:{idempotency or uuid.uuid4()}",
            "PIX por aproximação",
            channel="PROXIMITY",
            confirmed=confirmed,
            actor_id=actor_id,
        )

    def queue_webhook(self, event: str, payload: dict[str, Any], url: str = "sandbox://pix") -> str:
        identifier, secret = str(uuid.uuid4()), secrets.token_hex(16)
        raw = json.dumps(payload, sort_keys=True)
        signature = hmac.new(secret.encode(), raw.encode(), hashlib.sha256).hexdigest()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO pix_webhooks VALUES(?,?,?,?,?,?,?,?,?,?)",
                (identifier, url, secret, event, raw, signature, "PENDING", 0, utcnow(), None),
            )
        return identifier

    def deliver_webhooks(self, transport: Any | None = None) -> dict[str, int]:
        """Entrega os webhooks pendentes.

        Sem `transport`, marca como entregue no sandbox — comportamento
        histórico, mantido porque não há adquirente real neste ambiente. O nome
        anterior prometia entrega e apenas mudava o estado; agora o modo
        sandbox é explícito no retorno e um transporte real é injetável.

        `transport(url, payload, signature)` deve levantar exceção em falha.
        """
        now = utcnow()
        with self.db.connect() as con:
            pending = con.execute(
                "SELECT * FROM pix_webhooks WHERE state='PENDING' ORDER BY created_at"
            ).fetchall()
        if transport is None:
            with self.db.transaction() as con:
                count = con.execute(
                    "UPDATE pix_webhooks SET state='SENT',attempts=attempts+1,sent_at=? WHERE state='PENDING'",
                    (now,),
                ).rowcount
            return {"sent": count, "failed": 0, "mode": "SANDBOX"}
        sent = failed = 0
        for hook in pending:
            try:
                transport(hook["url"], hook["payload"], hook["signature"])
                state, sent = "SENT", sent + 1
            except Exception as exc:
                state = "FAILED" if hook["attempts"] + 1 >= self.MAX_WEBHOOK_ATTEMPTS else "PENDING"
                failed += 1
                LOGGER.warning(
                    "pix.webhook_delivery_failed",
                    extra={"webhook_id": hook["webhook_id"], "state": state, "error": type(exc).__name__},
                )
            with self.db.transaction() as con:
                con.execute(
                    "UPDATE pix_webhooks SET state=?,attempts=attempts+1,sent_at=? WHERE webhook_id=?",
                    (state, now if state == "SENT" else None, hook["webhook_id"]),
                )
        return {"sent": sent, "failed": failed, "mode": "TRANSPORT"}

    def reconcile_charge(self, txid: str, pix_id: str, received_cents: int) -> str:
        with self.db.connect() as con:
            charge = con.execute("SELECT amount_cents FROM pix_charges WHERE txid=?", (txid,)).fetchone()
        expected = charge[0] or received_cents
        state = "MATCHED" if expected == received_cents else "DIVERGENT"
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO pix_reconciliation VALUES(?,?,?,?,?,?,?)",
                (identifier, txid, pix_id, expected, received_cents, state, utcnow()),
            )
        return identifier
