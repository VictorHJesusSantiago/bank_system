"""Sandbox Open Finance com consentimento, assinatura e API HTTP local."""

from __future__ import annotations

import base64
import json
import secrets
import sqlite3
import uuid
from datetime import UTC, datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import urlparse

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from bank_observability import LOGGER, METRICS, TRACER, correlation
from bank_core import (
    AuthorizationError,
    BankDatabase,
    BankError,
    LedgerService,
    SecurityService,
    hash_token,
    utcnow,
)


ALL_SCOPES = {
    "CUSTOMERS_READ",
    "ACCOUNTS_READ",
    "TRANSACTIONS_READ",
    "CARDS_READ",
    "CREDIT_READ",
    "INVESTMENTS_READ",
    "FX_READ",
    "PENSION_READ",
    "INSURANCE_READ",
    "PAYMENTS_INITIATE",
    "CREDIT_PROPOSAL_CREATE",
}


class OpenFinanceService:
    MAX_SHARE_LIMIT = 500
    VAULT_PREFIX = "vault:"

    def __init__(
        self,
        db: BankDatabase,
        ledger: LedgerService,
        security: SecurityService | None = None,
        vault: Any | None = None,
    ):
        self.db, self.ledger, self.security = db, ledger, security
        self.vault = vault
        with db.transaction() as con:
            con.executescript(
                """
                CREATE TABLE IF NOT EXISTS of_participants(
                  participant_id TEXT PRIMARY KEY,name TEXT NOT NULL,base_url TEXT NOT NULL,
                  certificate_id TEXT NOT NULL,state TEXT NOT NULL,created_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS of_certificates(
                  certificate_id TEXT PRIMARY KEY,public_key TEXT NOT NULL,
                  private_key TEXT NOT NULL,state TEXT NOT NULL,expires_at TEXT NOT NULL,
                  created_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS of_api_clients(
                  client_id TEXT PRIMARY KEY,name TEXT NOT NULL,secret_hash TEXT NOT NULL,
                  scopes TEXT NOT NULL,rate_limit INTEGER NOT NULL,state TEXT NOT NULL,
                  created_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS of_consents(
                  consent_id TEXT PRIMARY KEY,user_id TEXT NOT NULL,client_id TEXT NOT NULL,
                  scopes TEXT NOT NULL,state TEXT NOT NULL,authenticated_at TEXT,
                  confirmed_at TEXT,expires_at TEXT NOT NULL,revoked_at TEXT,
                  created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS of_consent_history(
                  history_id TEXT PRIMARY KEY,consent_id TEXT NOT NULL,state TEXT NOT NULL,
                  actor TEXT NOT NULL,details TEXT NOT NULL,created_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS of_access_logs(
                  log_id TEXT PRIMARY KEY,consent_id TEXT,client_id TEXT NOT NULL,
                  correlation_id TEXT NOT NULL,operation TEXT NOT NULL,scope TEXT,
                  result TEXT NOT NULL,request_hash TEXT NOT NULL,created_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS of_rate_events(
                  client_id TEXT NOT NULL,occurred_at TEXT NOT NULL);
                CREATE INDEX IF NOT EXISTS idx_of_rate ON of_rate_events(client_id,occurred_at);
                CREATE TABLE IF NOT EXISTS of_external_data(
                  record_id TEXT PRIMARY KEY,user_id TEXT NOT NULL,institution TEXT NOT NULL,
                  data_type TEXT NOT NULL,payload TEXT NOT NULL,imported_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS of_payment_initiations(
                  initiation_id TEXT PRIMARY KEY,consent_id TEXT NOT NULL,
                  idempotency_key TEXT UNIQUE NOT NULL,transaction_id TEXT,
                  origin TEXT NOT NULL,destination TEXT NOT NULL,amount TEXT NOT NULL,
                  state TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS of_credit_proposals(
                  proposal_id TEXT PRIMARY KEY,consent_id TEXT NOT NULL,client_id TEXT NOT NULL,
                  amount TEXT NOT NULL,months INTEGER NOT NULL,purpose TEXT NOT NULL,
                  state TEXT NOT NULL,response TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
                """
            )

    def issue_certificate(self, days: int = 365) -> dict[str, str]:
        private = Ed25519PrivateKey.generate()
        private_raw = private.private_bytes(
            serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()
        ).decode()
        public_raw = (
            private.public_key()
            .public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)
            .decode()
        )
        certificate_id = str(uuid.uuid4())
        stored_private = self._store_private(private_raw)
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO of_certificates VALUES(?,?,?,?,?,?)",
                (
                    certificate_id,
                    public_raw,
                    stored_private,
                    "ACTIVE",
                    (datetime.now(UTC) + timedelta(days=days)).isoformat(),
                    utcnow(),
                ),
            )
        return {"certificate_id": certificate_id, "public_key": public_raw}

    def _store_private(self, pem: str) -> str:
        """Chave privada em claro no SQLite permite forjar assinaturas de quem
        obtiver o arquivo. Com cofre configurado, só o ciframento é persistido."""
        if not self.vault:
            return pem
        return self.VAULT_PREFIX + self.vault.encrypt("OF_PRIVATE_KEY", pem)

    def _read_private(self, stored: str) -> str:
        if not stored.startswith(self.VAULT_PREFIX):
            return stored
        if not self.vault:
            raise AuthorizationError("VAULT_UNAVAILABLE", "Chave privada cifrada exige cofre")
        return self.vault.decrypt(stored[len(self.VAULT_PREFIX) :]).decode("utf-8")

    def sign(self, certificate_id: str, payload: bytes) -> str:
        with self.db.connect() as con:
            row = con.execute(
                "SELECT * FROM of_certificates WHERE certificate_id=? AND state='ACTIVE'", (certificate_id,)
            ).fetchone()
        if not row or datetime.fromisoformat(row["expires_at"]) <= datetime.now(UTC):
            raise AuthorizationError("INVALID_CERTIFICATE", "Certificado inválido")
        key = serialization.load_pem_private_key(self._read_private(row["private_key"]).encode(), None)
        return base64.b64encode(key.sign(payload)).decode()

    def verify(self, certificate_id: str, payload: bytes, signature: str) -> bool:
        with self.db.connect() as con:
            row = con.execute(
                "SELECT public_key FROM of_certificates WHERE certificate_id=?", (certificate_id,)
            ).fetchone()
        if not row:
            return False
        try:
            key = serialization.load_pem_public_key(row[0].encode())
            key.verify(base64.b64decode(signature), payload)
            return True
        except Exception:
            return False

    def create_client(self, name: str, scopes: set[str], rate_limit: int = 100) -> dict[str, str]:
        if not scopes or not scopes <= ALL_SCOPES:
            raise BankError("INVALID_SCOPES", "Escopos inválidos")
        client_id, secret = str(uuid.uuid4()), secrets.token_urlsafe(48)
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO of_api_clients VALUES(?,?,?,?,?,?,?)",
                (
                    client_id,
                    name,
                    hash_token(secret),
                    json.dumps(sorted(scopes)),
                    rate_limit,
                    "ACTIVE",
                    utcnow(),
                ),
            )
        return {"client_id": client_id, "client_secret": secret}

    DEFAULT_RATE_LIMIT = 100

    def authenticate_client(self, client_id: str, secret: str) -> sqlite3.Row:
        with self.db.connect() as con:
            row = con.execute("SELECT * FROM of_api_clients WHERE client_id=?", (client_id,)).fetchone()
        self.rate_limit(client_id or "unknown", row["rate_limit"] if row else self.DEFAULT_RATE_LIMIT)
        if (
            not row
            or row["state"] != "ACTIVE"
            or not secrets.compare_digest(row["secret_hash"], hash_token(secret))
        ):
            raise AuthorizationError("INVALID_CLIENT", "Cliente de API inválido")
        return row

    def rate_limit(self, client_id: str, limit: int, window_seconds: int = 60) -> None:
        cutoff = (datetime.now(UTC) - timedelta(seconds=window_seconds)).isoformat()
        with self.db.transaction() as con:
            con.execute("DELETE FROM of_rate_events WHERE occurred_at<?", (cutoff,))
            count = con.execute(
                "SELECT COUNT(*) FROM of_rate_events WHERE client_id=? AND occurred_at>=?",
                (client_id, cutoff),
            ).fetchone()[0]
            if count >= limit:
                raise AuthorizationError("RATE_LIMITED", "Rate limit excedido")
            con.execute("INSERT INTO of_rate_events VALUES(?,?)", (client_id, utcnow()))

    def create_consent(self, user_id: str, client_id: str, scopes: set[str], minutes: int = 60) -> str:
        with self.db.connect() as con:
            client = con.execute(
                "SELECT scopes FROM of_api_clients WHERE client_id=?", (client_id,)
            ).fetchone()
        if not client or not scopes <= set(json.loads(client[0])):
            raise AuthorizationError("SCOPE_NOT_ALLOWED", "Escopo não autorizado ao cliente")
        consent_id, now = str(uuid.uuid4()), utcnow()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO of_consents VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                (
                    consent_id,
                    user_id,
                    client_id,
                    json.dumps(sorted(scopes)),
                    "AWAITING_AUTHENTICATION",
                    None,
                    None,
                    (datetime.now(UTC) + timedelta(minutes=minutes)).isoformat(),
                    None,
                    now,
                    now,
                ),
            )
            self._history(con, consent_id, "AWAITING_AUTHENTICATION", user_id, {})
        return consent_id

    def authenticate_consent(self, consent_id: str, user_id: str) -> None:
        self._change_consent(
            consent_id, user_id, "AWAITING_AUTHENTICATION", "AWAITING_CONFIRMATION", "authenticated_at"
        )

    def confirm_consent(self, consent_id: str, user_id: str) -> None:
        self._change_consent(consent_id, user_id, "AWAITING_CONFIRMATION", "AUTHORISED", "confirmed_at")

    TIMESTAMP_COLUMNS = {"authenticated_at", "confirmed_at"}

    def _change_consent(self, consent_id: str, user_id: str, current: str, target: str, column: str) -> None:
        if column not in self.TIMESTAMP_COLUMNS:
            raise BankError("INVALID_CONSENT_COLUMN", "Coluna de consentimento inválida")
        with self.db.transaction() as con:
            changed = con.execute(
                f"""UPDATE of_consents SET state=?,{column}=?,updated_at=?
              WHERE consent_id=? AND user_id=? AND state=?""",  # noqa: S608  # nosec B608
                (target, utcnow(), utcnow(), consent_id, user_id, current),
            ).rowcount
            if not changed:
                raise AuthorizationError("INVALID_CONSENT_STATE", "Estado do consentimento inválido")
            self._history(con, consent_id, target, user_id, {})

    def revoke_consent(self, consent_id: str, actor: str) -> None:
        with self.db.transaction() as con:
            changed = con.execute(
                """UPDATE of_consents SET state='REVOKED',revoked_at=?,updated_at=?
              WHERE consent_id=? AND state<>'REVOKED'""",
                (utcnow(), utcnow(), consent_id),
            ).rowcount
            if not changed:
                raise BankError("CONSENT_NOT_FOUND", "Consentimento não encontrado")
            self._history(con, consent_id, "REVOKED", actor, {})

    def _history(
        self, con: sqlite3.Connection, consent: str, state: str, actor: str, details: dict[str, Any]
    ) -> None:
        con.execute(
            "INSERT INTO of_consent_history VALUES(?,?,?,?,?,?)",
            (str(uuid.uuid4()), consent, state, actor, json.dumps(details, sort_keys=True), utcnow()),
        )

    def consent(self, consent_id: str, scope: str, client_id: str) -> sqlite3.Row:
        with self.db.connect() as con:
            row = con.execute(
                "SELECT * FROM of_consents WHERE consent_id=? AND client_id=?", (consent_id, client_id)
            ).fetchone()
        if (
            not row
            or row["state"] != "AUTHORISED"
            or datetime.fromisoformat(row["expires_at"]) <= datetime.now(UTC)
        ):
            raise AuthorizationError("CONSENT_INVALID", "Consentimento inválido ou expirado")
        if scope not in json.loads(row["scopes"]):
            raise AuthorizationError("SCOPE_MISSING", f"Escopo necessário: {scope}")
        return row

    def history(self, consent_id: str) -> list[dict[str, Any]]:
        with self.db.connect() as con:
            return [
                dict(row)
                for row in con.execute(
                    "SELECT * FROM of_consent_history WHERE consent_id=? ORDER BY created_at", (consent_id,)
                )
            ]

    def share(
        self,
        consent_id: str,
        client_id: str,
        scope: str,
        correlation_id: str,
        filters: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        consent = self.consent(consent_id, scope, client_id)
        user = consent["user_id"]
        filters = filters or {}
        with self.db.connect() as con:
            if scope == "ACCOUNTS_READ":
                rows = con.execute(
                    "SELECT account_number,kind,status,currency,ledger_balance_cents,blocked_balance_cents FROM customer_accounts WHERE owner_id=?",
                    (user,),
                ).fetchall()
            elif scope == "TRANSACTIONS_READ":
                rows = con.execute(
                    """SELECT DISTINCT t.transaction_id,t.kind,t.state,t.description,
                  t.accounting_date FROM ledger_transactions t JOIN ledger_entries e USING(transaction_id)
                  JOIN customer_accounts a ON a.account_number=e.customer_account WHERE a.owner_id=?
                  ORDER BY t.accounting_date DESC LIMIT ?""",
                    (user, max(1, min(self.MAX_SHARE_LIMIT, int(filters.get("limit", 100))))),
                ).fetchall()
            else:
                dtype = {
                    "CUSTOMERS_READ": "CUSTOMER",
                    "CARDS_READ": "CARD",
                    "CREDIT_READ": "CREDIT",
                    "INVESTMENTS_READ": "INVESTMENT",
                    "FX_READ": "FX",
                    "PENSION_READ": "PENSION",
                    "INSURANCE_READ": "INSURANCE",
                }[scope]
                rows = con.execute(
                    "SELECT institution,payload,imported_at FROM of_external_data WHERE user_id=? AND data_type=?",
                    (user, dtype),
                ).fetchall()
        data = [
            {**dict(row), "payload": json.loads(row["payload"]) if "payload" in row.keys() else None}
            for row in rows
        ]
        self.log(consent_id, client_id, correlation_id, "SHARE", scope, "SUCCESS", filters)
        return {"consent_id": consent_id, "scope": scope, "data": data}

    def import_external(
        self, user_id: str, institution: str, data_type: str, records: list[dict[str, Any]]
    ) -> int:
        if data_type not in {
            "CUSTOMER",
            "ACCOUNT",
            "TRANSACTION",
            "CARD",
            "CREDIT",
            "INVESTMENT",
            "FX",
            "PENSION",
            "INSURANCE",
        }:
            raise BankError("INVALID_DATA_TYPE", "Tipo de dado inválido")
        with self.db.transaction() as con:
            for record in records:
                con.execute(
                    "INSERT INTO of_external_data VALUES(?,?,?,?,?,?)",
                    (
                        str(uuid.uuid4()),
                        user_id,
                        institution,
                        data_type,
                        json.dumps(record, sort_keys=True),
                        utcnow(),
                    ),
                )
        return len(records)

    def aggregate(self, user_id: str) -> dict[str, Any]:
        with self.db.connect() as con:
            internal = con.execute(
                "SELECT account_number,currency,ledger_balance_cents FROM customer_accounts WHERE owner_id=?",
                (user_id,),
            ).fetchall()
            external = con.execute(
                "SELECT institution,data_type,payload FROM of_external_data WHERE user_id=?", (user_id,)
            ).fetchall()
        balances = [
            {
                "institution": "Banco COBOL",
                "account": r["account_number"],
                "currency": r["currency"],
                "balance_cents": r["ledger_balance_cents"],
            }
            for r in internal
        ]
        products: dict[str, list[Any]] = {}
        for row in external:
            payload = json.loads(row["payload"])
            payload["institution"] = row["institution"]
            products.setdefault(row["data_type"], []).append(payload)
            if row["data_type"] == "ACCOUNT":
                balances.append(payload)
        return {
            "user_id": user_id,
            "balances": balances,
            "products": products,
            "total_brl_cents": sum(
                int(item.get("balance_cents", 0)) for item in balances if item.get("currency", "BRL") == "BRL"
            ),
        }

    def initiate_payment(
        self, consent_id: str, client_id: str, idempotency: str, origin: str, destination: str, amount: str
    ) -> dict[str, str]:
        consent = self.consent(consent_id, "PAYMENTS_INITIATE", client_id)
        with self.db.connect() as con:
            owned = con.execute(
                "SELECT 1 FROM customer_accounts WHERE account_number=? AND owner_id=?",
                (origin, consent["user_id"]),
            ).fetchone()
        if not owned:
            raise AuthorizationError("ORIGIN_NOT_CONSENTED", "Conta de origem fora do consentimento")
        initiation_id = str(uuid.uuid4())
        now = utcnow()
        with self.db.transaction() as con:
            existing = con.execute(
                "SELECT * FROM of_payment_initiations WHERE idempotency_key=?", (idempotency,)
            ).fetchone()
            if existing:
                return {
                    "initiation_id": existing["initiation_id"],
                    "transaction_id": existing["transaction_id"],
                    "state": existing["state"],
                }
            con.execute(
                "INSERT INTO of_payment_initiations VALUES(?,?,?,?,?,?,?,?,?,?)",
                (
                    initiation_id,
                    consent_id,
                    idempotency,
                    None,
                    origin,
                    destination,
                    str(amount),
                    "PROCESSING",
                    now,
                    now,
                ),
            )
        try:
            transaction = self.ledger.transfer(
                origin, destination, amount, f"of:{idempotency}", kind="OPEN_FINANCE_PAYMENT"
            )
            state = "SETTLED"
        except Exception:
            with self.db.transaction() as con:
                con.execute(
                    "UPDATE of_payment_initiations SET state='FAILED',updated_at=? WHERE initiation_id=?",
                    (utcnow(), initiation_id),
                )
            raise
        with self.db.transaction() as con:
            con.execute(
                "UPDATE of_payment_initiations SET transaction_id=?,state=?,updated_at=? WHERE initiation_id=?",
                (transaction, state, utcnow(), initiation_id),
            )
        return {"initiation_id": initiation_id, "transaction_id": transaction, "state": state}

    def credit_proposal(self, consent_id: str, client_id: str, amount: str, months: int, purpose: str) -> str:
        self.consent(consent_id, "CREDIT_PROPOSAL_CREATE", client_id)
        proposal = str(uuid.uuid4())
        now = utcnow()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO of_credit_proposals VALUES(?,?,?,?,?,?,?,?,?,?)",
                (
                    proposal,
                    consent_id,
                    client_id,
                    str(amount),
                    months,
                    purpose,
                    "FORWARDED",
                    json.dumps({"sandbox": True, "estimated_rate": "1.99"}),
                    now,
                    now,
                ),
            )
        return proposal

    def log(
        self,
        consent: str | None,
        client: str,
        correlation: str,
        operation: str,
        scope: str | None,
        result: str,
        request: dict[str, Any],
    ) -> None:
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO of_access_logs VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    str(uuid.uuid4()),
                    consent,
                    client,
                    correlation,
                    operation,
                    scope,
                    result,
                    hashlib_sha256(json.dumps(request, sort_keys=True)),
                    utcnow(),
                ),
            )

    def synthetic_data(self, seed: int = 42) -> dict[str, Any]:
        return {
            "seed": seed,
            "customers": [{"id": f"syn-{seed}-1", "name": "CLIENTE SINTETICO", "document": "00000000000"}],
            "accounts": [{"id": f"acc-{seed}-1", "balance_cents": seed * 100, "currency": "BRL"}],
        }

    @staticmethod
    def openapi() -> dict[str, Any]:
        paths = {
            "/health": {"get": {"summary": "Health check"}},
            "/open-finance/consents": {"post": {"summary": "Criar consentimento"}},
            "/open-finance/accounts": {"get": {"summary": "Compartilhar contas"}},
            "/open-finance/payments": {"post": {"summary": "Iniciar pagamento"}},
            "/open-finance/credit-proposals": {"post": {"summary": "Encaminhar crédito"}},
        }
        return {
            "openapi": "3.1.0",
            "info": {"title": "Banco COBOL Open Finance Sandbox", "version": "1.0.0"},
            "servers": [{"url": "http://127.0.0.1:8090"}],
            "paths": paths,
        }


def hashlib_sha256(value: str) -> str:
    import hashlib

    return hashlib.sha256(value.encode()).hexdigest()


class OpenFinanceAPI:
    """Aplicação HTTP testável sem iniciar socket."""

    def __init__(self, service: OpenFinanceService):
        self.service = service

    def handle(
        self, method: str, path: str, headers: dict[str, str], body: dict[str, Any] | None = None
    ) -> tuple[int, dict[str, Any]]:
        correlation_id = headers.get("X-Correlation-ID", str(uuid.uuid4()))
        with (
            correlation(correlation_id),
            TRACER.start("http.server.request", **{"http.method": method, "http.route": path}) as span,
            METRICS.timer("http_request_duration_ms", method=method, path=path),
        ):
            status, payload = self._route(method, path, headers, body, correlation_id)
            span.set_attribute("http.status_code", status)
        METRICS.increment("http_requests_total", method=method, path=path, status=str(status))
        LOGGER.info("http.request", extra={"method": method, "path": path, "status": status})
        return status, payload

    def _route(
        self, method: str, path: str, headers: dict[str, str], body: dict[str, Any] | None, correlation: str
    ) -> tuple[int, dict[str, Any]]:
        try:
            if path == "/health":
                return 200, {"status": "UP", "database": self.service.db.integrity_check()["ok"]}
            if path == "/ready":
                return 200, {"ready": True}
            if path == "/metrics":
                return 200, METRICS.snapshot()
            if path == "/openapi.json":
                return 200, self.service.openapi()
            client = self.service.authenticate_client(
                headers.get("X-Client-ID", ""), headers.get("X-Client-Secret", "")
            )
            if method == "POST" and path == "/open-finance/consents":
                consent = self.service.create_consent(
                    body["user_id"], client["client_id"], set(body["scopes"]), body.get("minutes", 60)
                )
                return 201, {"consent_id": consent, "correlation_id": correlation}
            if method == "GET" and path == "/open-finance/accounts":
                return 200, self.service.share(
                    headers["X-Consent-ID"], client["client_id"], "ACCOUNTS_READ", correlation
                )
            if method == "POST" and path == "/open-finance/payments":
                return 201, self.service.initiate_payment(
                    headers["X-Consent-ID"],
                    client["client_id"],
                    headers["Idempotency-Key"],
                    body["origin"],
                    body["destination"],
                    body["amount"],
                )
            return 404, {"code": "NOT_FOUND", "correlation_id": correlation}
        except AuthorizationError as exc:
            return 403, {"code": exc.code, "message": str(exc), "correlation_id": correlation}
        except BankError as exc:
            return 400, {"code": exc.code, "message": str(exc), "correlation_id": correlation}
        except (KeyError, TypeError, ValueError) as exc:
            return 400, {"code": "INVALID_REQUEST", "message": str(exc), "correlation_id": correlation}
        except Exception:
            LOGGER.exception(
                "http.unhandled_error", extra={"method": method, "path": path, "correlation_id": correlation}
            )
            return 500, {"code": "INTERNAL_ERROR", "correlation_id": correlation}


def serve(api: OpenFinanceAPI, host: str = "127.0.0.1", port: int = 8090) -> ThreadingHTTPServer:
    MAX_BODY_BYTES = 1024 * 1024

    class Handler(BaseHTTPRequestHandler):
        def process(self) -> None:
            length = int(self.headers.get("Content-Length", "0"))
            if length > MAX_BODY_BYTES:
                raw = json.dumps({"code": "PAYLOAD_TOO_LARGE"}).encode()
                self.send_response(413)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)
                return
            try:
                body = json.loads(self.rfile.read(length) or b"{}")
            except json.JSONDecodeError:
                body = {}
            status, payload = api.handle(
                self.command, urlparse(self.path).path, dict(self.headers.items()), body
            )
            raw = json.dumps(payload, ensure_ascii=False).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        do_GET = process
        do_POST = process

        def log_message(self, *_: Any) -> None:
            return

    server = ThreadingHTTPServer((host, port), Handler)
    return server
