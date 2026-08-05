"""Núcleo transacional e de segurança do Banco COBOL.

Este módulo complementa os módulos COBOL legados com uma camada ACID. Valores
monetários são armazenados em centavos; nenhuma operação financeira usa float.
SQLite fornece journal durável, rollback, recuperação após crash e concorrência
multi-processo em uma única máquina.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import re
import secrets
import sqlite3
import struct
import threading
import time
import uuid
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from decimal import Decimal, ROUND_HALF_EVEN
from pathlib import Path
from typing import Any, Iterable, Iterator, Sequence

from bank_observability import LOGGER, METRICS, TRACER

try:
    from argon2 import PasswordHasher
    from argon2.exceptions import InvalidHashError, VerifyMismatchError
except ImportError:  # pragma: no cover - validado explicitamente em runtime
    PasswordHasher = None  # type: ignore[assignment,misc]
    InvalidHashError = VerifyMismatchError = ValueError  # type: ignore[assignment,misc]


SCHEMA_VERSION = 1
SYSTEM_ACCOUNTS = {
    "CASH": ("ATIVO", "Caixa e disponibilidades"),
    "CUSTOMER_DEPOSITS": ("PASSIVO", "Depósitos de clientes"),
    "BLOCKED_FUNDS": ("PASSIVO", "Recursos bloqueados"),
    "FEE_REVENUE": ("RECEITA", "Receitas de tarifas"),
    "INTEREST_REVENUE": ("RECEITA", "Receitas de juros"),
    "OPERATING_EXPENSE": ("DESPESA", "Despesas operacionais"),
    "CREDIT_PORTFOLIO": ("ATIVO", "Carteira de crédito"),
    "LOSS_PROVISION": ("PROVISAO", "Provisão para perdas"),
    "INVESTMENT_CUSTODY": ("PASSIVO", "Custódia de investimentos"),
    "INSURANCE_PAYABLE": ("PASSIVO", "Prêmios e indenizações"),
    "SETTLEMENT": ("TRANSITORIA", "Compensação e liquidação"),
}
SATELLITE_KINDS = {
    "DONATION",
    "RECURRING_DONATION",
    "SAVINGS_BOX",
    "CASHBACK",
    "AUTOMATIC_DEBIT",
    "CHEQUE_CLEARING",
    "CHEQUE_RETURN",
    "INSURANCE_PREMIUM",
    "INSURANCE_CLAIM",
    "CONSORTIUM_INSTALLMENT",
    "CONSORTIUM_BID",
    "PENSION_CONTRIBUTION",
    "PENSION_REDEMPTION",
    "CAPITALIZATION_INSTALLMENT",
    "CAPITALIZATION_REDEMPTION",
    "CAPITALIZATION_PRIZE",
    "FGTS_WITHDRAWAL",
    "FGTS_ADVANCE",
    "COLLECTION_SETTLEMENT",
    "OVERDRAFT",
    "PAYROLL_LOAN",
    "DEBT_RENEGOTIATION",
    "PORTABILITY",
    "BUSINESS_ACCOUNT",
    "FX_BUY",
    "FX_SELL",
    "SWIFT_TRANSFER",
    "INVESTMENT_APPLICATION",
    "INVESTMENT_REDEMPTION",
    "LOYALTY_REWARD",
    "BOLETO_PAYMENT",
    "CARD_BILL_PAYMENT",
    "LOAN_INSTALLMENT",
    "OVERDRAFT_DRAW",
    "PAYROLL_LOAN_INSTALLMENT",
}
SENSITIVE_ACTIONS = {
    "ADMIN_ADJUSTMENT",
    "ROLE_CHANGE",
    "LIMIT_INCREASE",
    "ACCOUNT_CLOSE",
    "LARGE_TRANSFER",
    "AUDIT_EXPORT",
    "CREDENTIAL_RESET",
}


class BankError(RuntimeError):
    """Erro de domínio com código estável."""

    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


class AuthenticationError(BankError):
    pass


class AuthorizationError(BankError):
    pass


class AccountingError(BankError):
    pass


def utcnow() -> str:
    return datetime.now(UTC).isoformat(timespec="microseconds")


@dataclass(frozen=True, order=True)
class Money:
    """Valor monetário explícito em centavos.

    Existe para desfazer a ambiguidade de ``money_to_cents``: um ``int`` nu é
    tratado como centavos, então ``100`` significa R$1,00 e não R$100,00. Onde o
    tipo é usado a unidade fica declarada na assinatura e o erro deixa de ser
    possível. Imutável e comparável por valor.
    """

    cents: int
    currency: str = "BRL"

    @classmethod
    def from_cents(cls, cents: int, currency: str = "BRL") -> "Money":
        if not isinstance(cents, int) or isinstance(cents, bool):
            raise AccountingError("INVALID_AMOUNT", "Centavos devem ser inteiros")
        return cls(cents, currency)

    @classmethod
    def parse(cls, value: "Decimal | str | Money", currency: str = "BRL") -> "Money":
        """Interpreta uma quantia na unidade humana: ``parse('100')`` = R$100,00."""
        if isinstance(value, Money):
            return value
        if isinstance(value, int) and not isinstance(value, bool):
            raise AccountingError(
                "AMBIGUOUS_AMOUNT",
                "Use Money.from_cents para centavos ou uma string/Decimal para reais",
            )
        return cls(money_to_cents(value), currency)

    def _same_currency(self, other: "Money") -> None:
        if self.currency != other.currency:
            raise AccountingError("CURRENCY_MISMATCH", "Moedas diferentes não se somam")

    def __add__(self, other: "Money") -> "Money":
        self._same_currency(other)
        return Money(self.cents + other.cents, self.currency)

    def __sub__(self, other: "Money") -> "Money":
        self._same_currency(other)
        return Money(self.cents - other.cents, self.currency)

    def __neg__(self) -> "Money":
        return Money(-self.cents, self.currency)

    @property
    def amount(self) -> Decimal:
        return cents_to_money(self.cents)

    def __str__(self) -> str:
        return f"{self.amount:.2f}"


def money_to_cents(value: "Decimal | str | int | Money") -> int:
    """Converte para centavos.

    ATENÇÃO: ``int`` é repassado como JÁ SENDO centavos — é o que permite
    encadear serviços sem dupla conversão. Para novos códigos prefira ``Money``,
    que torna a unidade explícita.
    """
    if isinstance(value, Money):
        return value.cents
    if isinstance(value, int):
        return value
    try:
        decimal = Decimal(str(value).replace(",", "."))
    except Exception as exc:
        raise AccountingError("INVALID_AMOUNT", "Valor monetário inválido") from exc
    if not decimal.is_finite():
        raise AccountingError("INVALID_AMOUNT", "Valor monetário deve ser finito")
    return int((decimal * 100).quantize(Decimal("1"), rounding=ROUND_HALF_EVEN))


def cents_to_money(value: int) -> Decimal:
    return (Decimal(value) / Decimal(100)).quantize(Decimal("0.01"))


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class Posting:
    account_code: str
    debit_cents: int = 0
    credit_cents: int = 0
    customer_account: str | None = None
    memo: str = ""

    def validate(self) -> None:
        if self.debit_cents < 0 or self.credit_cents < 0:
            raise AccountingError("NEGATIVE_POSTING", "Lançamento não aceita valor negativo")
        if bool(self.debit_cents) == bool(self.credit_cents):
            raise AccountingError("INVALID_POSTING", "Informe exatamente um débito ou um crédito")


@dataclass(frozen=True)
class Account:
    """Entidade Conta — dona das suas próprias regras de saldo.

    A fórmula do saldo disponível estava repetida em quatro pontos de
    ``LedgerService``, cada um livre para divergir (e um deles divergia, ao
    somar a reserva sendo capturada). Concentrá-la aqui torna a regra única e
    testável sem banco: a conta responde sobre a conta.
    """

    account_number: str
    owner_id: str
    kind: str
    status: str
    currency: str
    ledger_balance_cents: int
    blocked_balance_cents: int
    projected_balance_cents: int
    overdraft_limit_cents: int
    version: int

    @classmethod
    def from_row(cls, row: sqlite3.Row) -> "Account":
        return cls(
            account_number=row["account_number"],
            owner_id=row["owner_id"],
            kind=row["kind"],
            status=row["status"],
            currency=row["currency"],
            ledger_balance_cents=int(row["ledger_balance_cents"]),
            blocked_balance_cents=int(row["blocked_balance_cents"]),
            projected_balance_cents=int(row["projected_balance_cents"]),
            overdraft_limit_cents=int(row["overdraft_limit_cents"]),
            version=int(row["version"]),
        )

    @property
    def is_active(self) -> bool:
        return self.status == "ACTIVE"

    @property
    def available_cents(self) -> int:
        """Saldo utilizável: razão, menos o bloqueado, mais o cheque especial."""
        return self.ledger_balance_cents - self.blocked_balance_cents + self.overdraft_limit_cents

    @property
    def available(self) -> Money:
        return Money.from_cents(self.available_cents, self.currency)

    @property
    def ledger_balance(self) -> Money:
        return Money.from_cents(self.ledger_balance_cents, self.currency)

    def available_for_capture_cents(self, hold_remaining_cents: int) -> int:
        """A reserva já garantiu o valor; os demais bloqueios seguem retidos."""
        return self.available_cents + hold_remaining_cents

    def ensure_can_apply(self, delta_cents: int) -> None:
        """Invariante de movimentação: conta ativa e saldo suficiente."""
        if not self.is_active:
            raise AccountingError("ACCOUNT_BLOCKED", f"Conta {self.account_number} não está ativa")
        if delta_cents < 0 and self.available_cents + delta_cents < 0:
            raise AccountingError("INSUFFICIENT_FUNDS", "Saldo disponível insuficiente")

    def ensure_can_hold(self, amount_cents: int) -> None:
        if self.available_cents < amount_cents:
            raise AccountingError("INSUFFICIENT_FUNDS", "Saldo insuficiente para reserva")

    def as_dict(self) -> dict[str, Any]:
        """Projeção para a CLI/GUI, que consomem dicionários."""
        return {
            "account_number": self.account_number,
            "owner_id": self.owner_id,
            "kind": self.kind,
            "status": self.status,
            "currency": self.currency,
            "ledger_balance_cents": self.ledger_balance_cents,
            "blocked_balance_cents": self.blocked_balance_cents,
            "projected_balance_cents": self.projected_balance_cents,
            "overdraft_limit_cents": self.overdraft_limit_cents,
            "version": self.version,
            "ledger_balance": cents_to_money(self.ledger_balance_cents),
            "blocked_balance": cents_to_money(self.blocked_balance_cents),
            "available_balance": cents_to_money(self.available_cents),
            "projected_balance": cents_to_money(self.projected_balance_cents),
        }


@dataclass(frozen=True)
class Hold:
    """Entidade Reserva — sabe quanto ainda pode ser capturado."""

    hold_id: str
    account_number: str
    amount_cents: int
    captured_cents: int
    state: str
    reason: str

    @classmethod
    def from_row(cls, row: sqlite3.Row) -> "Hold":
        return cls(
            hold_id=row["hold_id"],
            account_number=row["account_number"],
            amount_cents=int(row["amount_cents"]),
            captured_cents=int(row["captured_cents"]),
            state=row["state"],
            reason=row["reason"],
        )

    @property
    def is_active(self) -> bool:
        return self.state == "ACTIVE"

    @property
    def remaining_cents(self) -> int:
        return self.amount_cents - self.captured_cents

    def state_after_capturing(self, amount_cents: int) -> str:
        return "CAPTURED" if self.captured_cents + amount_cents == self.amount_cents else "ACTIVE"

    def ensure_capturable(self, amount_cents: int) -> None:
        if amount_cents <= 0 or amount_cents > self.remaining_cents:
            raise AccountingError("INVALID_CAPTURE", "Captura excede a reserva")


class ClosingConnection(sqlite3.Connection):
    """Connection cujo uso em ``with`` também fecha o arquivo no Windows."""

    def __exit__(self, exc_type: Any, exc: Any, traceback: Any) -> bool:
        try:
            return super().__exit__(exc_type, exc, traceback)
        finally:
            self.close()


class PooledConnection(sqlite3.Connection):
    """Connection que, ao sair do ``with``, volta ao pool em vez de fechar.

    Mantém a semântica de ``ClosingConnection`` para o chamador — o bloco
    termina e a conexão deixa de ser usável por ele — sem pagar a abertura do
    arquivo e os PRAGMAs a cada operação.
    """

    _database: Any = None

    def __exit__(self, exc_type: Any, exc: Any, traceback: Any) -> bool:
        try:
            return super().__exit__(exc_type, exc, traceback)
        finally:
            if self._database is not None:
                self._database._release(self)
            else:  # pragma: no cover - conexão sem pool associado
                self.close()


class BankDatabase:
    """Banco transacional, migrações, integridade e manutenção."""

    _PERSISTENT_PRAGMAS = ("PRAGMA journal_mode = WAL",)
    _CONNECTION_PRAGMAS = (
        "PRAGMA foreign_keys = ON",
        "PRAGMA busy_timeout = 30000",
        "PRAGMA synchronous = FULL",
    )

    def __init__(self, path: str | Path = "BANKCORE.db", pool_size: int = 4):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._pool_size = max(0, pool_size)
        self._local = threading.local()
        self._all_pooled: list[sqlite3.Connection] = []
        self._pool_lock = threading.Lock()
        self._apply_persistent_pragmas()
        self._initialize()

    def _apply_persistent_pragmas(self) -> None:
        connection = sqlite3.connect(self.path, timeout=30, isolation_level=None)
        try:
            for pragma in self._PERSISTENT_PRAGMAS:
                connection.execute(pragma)
        finally:
            connection.close()

    def _new_connection(self, pooled: bool) -> sqlite3.Connection:
        connection = sqlite3.connect(
            self.path,
            timeout=30,
            isolation_level=None,
            check_same_thread=False,
            factory=PooledConnection if pooled else ClosingConnection,
        )
        connection.row_factory = sqlite3.Row
        for pragma in self._CONNECTION_PRAGMAS:
            connection.execute(pragma)
        if pooled:
            connection._database = self  # type: ignore[attr-defined]
            with self._pool_lock:
                self._all_pooled.append(connection)
        return connection

    def _idle(self) -> list[sqlite3.Connection]:
        idle = getattr(self._local, "idle", None)
        if idle is None:
            idle = self._local.idle = []
        return idle

    def _acquire(self) -> sqlite3.Connection:
        if self._pool_size == 0:
            return self._new_connection(pooled=False)
        idle = self._idle()
        if idle:
            METRICS.increment("db_pool_hits_total")
            return idle.pop()
        METRICS.increment("db_pool_misses_total")
        return self._new_connection(pooled=True)

    def _release(self, connection: sqlite3.Connection) -> None:
        """Devolve ao pool; descarta a conexão se ela voltar suja."""
        idle = self._idle()
        if connection.in_transaction or len(idle) >= self._pool_size:
            self._discard(connection)
            return
        idle.append(connection)

    def _discard(self, connection: sqlite3.Connection) -> None:
        with self._pool_lock:
            if connection in self._all_pooled:
                self._all_pooled.remove(connection)
        try:
            connection.close()
        except sqlite3.Error:  # pragma: no cover - fechar já fechada é inócuo
            pass

    def close_pool(self) -> None:
        """Fecha todas as conexões ociosas.

        Obrigatório antes de ``VACUUM``, remoção do arquivo ou fim de teste no
        Windows, onde um handle aberto impede a operação — é a mesma razão de
        ``ClosingConnection`` existir.
        """
        with self._pool_lock:
            connections, self._all_pooled = list(self._all_pooled), []
        for connection in connections:
            try:
                connection.close()
            except sqlite3.Error:  # pragma: no cover
                pass
        self._local.idle = []

    def connect(self) -> sqlite3.Connection:
        return self._acquire()

    @contextmanager
    def transaction(self, immediate: bool = True) -> Iterator[sqlite3.Connection]:
        connection = self._acquire()
        try:
            connection.execute("BEGIN IMMEDIATE" if immediate else "BEGIN")
            yield connection
            if connection.in_transaction:
                connection.execute("COMMIT")
        except Exception:
            if connection.in_transaction:
                connection.execute("ROLLBACK")
            raise
        finally:
            self._release(connection)

    def _initialize(self) -> None:
        with self.transaction() as con:
            con.executescript(
                """
                CREATE TABLE IF NOT EXISTS schema_migrations (
                    version INTEGER PRIMARY KEY,
                    applied_at TEXT NOT NULL,
                    checksum TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS chart_accounts (
                    code TEXT PRIMARY KEY,
                    category TEXT NOT NULL,
                    name TEXT NOT NULL,
                    active INTEGER NOT NULL DEFAULT 1
                );
                CREATE TABLE IF NOT EXISTS customer_accounts (
                    account_number TEXT PRIMARY KEY,
                    owner_id TEXT NOT NULL,
                    kind TEXT NOT NULL,
                    status TEXT NOT NULL DEFAULT 'ACTIVE',
                    currency TEXT NOT NULL DEFAULT 'BRL',
                    ledger_balance_cents INTEGER NOT NULL DEFAULT 0,
                    blocked_balance_cents INTEGER NOT NULL DEFAULT 0,
                    projected_balance_cents INTEGER NOT NULL DEFAULT 0,
                    overdraft_limit_cents INTEGER NOT NULL DEFAULT 0,
                    version INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS ledger_transactions (
                    transaction_id TEXT PRIMARY KEY,
                    idempotency_key TEXT NOT NULL UNIQUE,
                    kind TEXT NOT NULL,
                    state TEXT NOT NULL,
                    description TEXT NOT NULL,
                    effective_at TEXT NOT NULL,
                    accounting_date TEXT NOT NULL,
                    settlement_at TEXT,
                    original_transaction_id TEXT,
                    metadata TEXT NOT NULL DEFAULT '{}',
                    created_by TEXT,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY(original_transaction_id)
                        REFERENCES ledger_transactions(transaction_id)
                );
                CREATE TABLE IF NOT EXISTS ledger_entries (
                    entry_id TEXT PRIMARY KEY,
                    transaction_id TEXT NOT NULL,
                    sequence INTEGER NOT NULL,
                    account_code TEXT NOT NULL,
                    customer_account TEXT,
                    debit_cents INTEGER NOT NULL DEFAULT 0,
                    credit_cents INTEGER NOT NULL DEFAULT 0,
                    memo TEXT NOT NULL DEFAULT '',
                    created_at TEXT NOT NULL,
                    UNIQUE(transaction_id, sequence),
                    FOREIGN KEY(transaction_id)
                        REFERENCES ledger_transactions(transaction_id),
                    FOREIGN KEY(account_code) REFERENCES chart_accounts(code),
                    FOREIGN KEY(customer_account)
                        REFERENCES customer_accounts(account_number),
                    CHECK(debit_cents >= 0 AND credit_cents >= 0),
                    CHECK((debit_cents > 0 AND credit_cents = 0)
                       OR (credit_cents > 0 AND debit_cents = 0))
                );
                CREATE TABLE IF NOT EXISTS balance_events (
                    event_id TEXT PRIMARY KEY,
                    transaction_id TEXT NOT NULL,
                    account_number TEXT NOT NULL,
                    previous_cents INTEGER NOT NULL,
                    delta_cents INTEGER NOT NULL,
                    resulting_cents INTEGER NOT NULL,
                    event_hash TEXT NOT NULL,
                    previous_hash TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY(transaction_id)
                        REFERENCES ledger_transactions(transaction_id),
                    FOREIGN KEY(account_number)
                        REFERENCES customer_accounts(account_number)
                );
                CREATE TABLE IF NOT EXISTS holds (
                    hold_id TEXT PRIMARY KEY,
                    account_number TEXT NOT NULL,
                    amount_cents INTEGER NOT NULL,
                    captured_cents INTEGER NOT NULL DEFAULT 0,
                    state TEXT NOT NULL,
                    reason TEXT NOT NULL,
                    expires_at TEXT,
                    transaction_id TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    FOREIGN KEY(account_number)
                        REFERENCES customer_accounts(account_number)
                );
                CREATE TABLE IF NOT EXISTS scheduled_jobs (
                    job_id TEXT PRIMARY KEY,
                    kind TEXT NOT NULL,
                    payload TEXT NOT NULL,
                    recurrence TEXT NOT NULL,
                    next_run_at TEXT NOT NULL,
                    end_at TEXT,
                    state TEXT NOT NULL,
                    attempts INTEGER NOT NULL DEFAULT 0,
                    last_error TEXT,
                    idempotency_prefix TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    anchor_day INTEGER
                );
                CREATE TABLE IF NOT EXISTS close_periods (
                    period TEXT PRIMARY KEY,
                    close_type TEXT NOT NULL,
                    closed_at TEXT NOT NULL,
                    closed_by TEXT NOT NULL,
                    trial_balance_debits INTEGER NOT NULL,
                    trial_balance_credits INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS users (
                    user_id TEXT PRIMARY KEY,
                    username TEXT NOT NULL UNIQUE,
                    cpf_cnpj TEXT UNIQUE,
                    password_hash TEXT NOT NULL,
                    password_changed_at TEXT NOT NULL,
                    failed_attempts INTEGER NOT NULL DEFAULT 0,
                    locked_until TEXT,
                    active INTEGER NOT NULL DEFAULT 1,
                    admin_password_expires_at TEXT,
                    totp_secret TEXT,
                    totp_enabled INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS password_history (
                    history_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    password_hash TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY(user_id) REFERENCES users(user_id)
                );
                CREATE TABLE IF NOT EXISTS sessions (
                    session_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    token_hash TEXT NOT NULL UNIQUE,
                    refresh_hash TEXT NOT NULL UNIQUE,
                    device TEXT NOT NULL,
                    ip_address TEXT,
                    created_at TEXT NOT NULL,
                    last_seen_at TEXT NOT NULL,
                    expires_at TEXT NOT NULL,
                    idle_expires_at TEXT NOT NULL,
                    revoked_at TEXT,
                    FOREIGN KEY(user_id) REFERENCES users(user_id)
                );
                CREATE TABLE IF NOT EXISTS used_totp_codes (
                    user_id TEXT NOT NULL,
                    code_hash TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    PRIMARY KEY(user_id, code_hash)
                );
                CREATE TABLE IF NOT EXISTS recovery_codes (
                    code_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    code_hash TEXT NOT NULL UNIQUE,
                    used_at TEXT,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY(user_id) REFERENCES users(user_id)
                );
                CREATE TABLE IF NOT EXISTS reset_tokens (
                    token_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    token_hash TEXT NOT NULL UNIQUE,
                    expires_at TEXT NOT NULL,
                    used_at TEXT,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY(user_id) REFERENCES users(user_id)
                );
                CREATE TABLE IF NOT EXISTS roles (
                    role TEXT PRIMARY KEY,
                    description TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS permissions (
                    permission TEXT PRIMARY KEY,
                    description TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS user_roles (
                    user_id TEXT NOT NULL,
                    role TEXT NOT NULL,
                    PRIMARY KEY(user_id, role),
                    FOREIGN KEY(user_id) REFERENCES users(user_id),
                    FOREIGN KEY(role) REFERENCES roles(role)
                );
                CREATE TABLE IF NOT EXISTS role_permissions (
                    role TEXT NOT NULL,
                    permission TEXT NOT NULL,
                    PRIMARY KEY(role, permission),
                    FOREIGN KEY(role) REFERENCES roles(role),
                    FOREIGN KEY(permission) REFERENCES permissions(permission)
                );
                CREATE TABLE IF NOT EXISTS account_access (
                    user_id TEXT NOT NULL,
                    account_number TEXT NOT NULL,
                    relationship TEXT NOT NULL,
                    valid_from TEXT NOT NULL,
                    valid_until TEXT,
                    permissions TEXT NOT NULL,
                    PRIMARY KEY(user_id, account_number, relationship),
                    FOREIGN KEY(user_id) REFERENCES users(user_id),
                    FOREIGN KEY(account_number)
                        REFERENCES customer_accounts(account_number)
                );
                CREATE TABLE IF NOT EXISTS approvals (
                    approval_id TEXT PRIMARY KEY,
                    action TEXT NOT NULL,
                    resource_id TEXT NOT NULL,
                    payload TEXT NOT NULL,
                    requested_by TEXT NOT NULL,
                    approved_by TEXT,
                    state TEXT NOT NULL,
                    expires_at TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    decided_at TEXT,
                    FOREIGN KEY(requested_by) REFERENCES users(user_id),
                    FOREIGN KEY(approved_by) REFERENCES users(user_id)
                );
                CREATE TABLE IF NOT EXISTS audit_events (
                    sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                    event_id TEXT NOT NULL UNIQUE,
                    actor_id TEXT,
                    action TEXT NOT NULL,
                    resource TEXT NOT NULL,
                    result TEXT NOT NULL,
                    details TEXT NOT NULL,
                    previous_hash TEXT NOT NULL,
                    event_hash TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS outbox (
                    message_id TEXT PRIMARY KEY,
                    channel TEXT NOT NULL,
                    recipient TEXT NOT NULL,
                    template TEXT NOT NULL,
                    payload TEXT NOT NULL,
                    state TEXT NOT NULL,
                    attempts INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL,
                    sent_at TEXT
                );
                CREATE TABLE IF NOT EXISTS module_events (
                    event_id TEXT PRIMARY KEY,
                    module TEXT NOT NULL,
                    kind TEXT NOT NULL,
                    account_number TEXT,
                    amount_cents INTEGER NOT NULL,
                    transaction_id TEXT,
                    payload TEXT NOT NULL,
                    state TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY(transaction_id)
                        REFERENCES ledger_transactions(transaction_id)
                );
                CREATE INDEX IF NOT EXISTS idx_ledger_entries_customer
                    ON ledger_entries(customer_account);
                CREATE INDEX IF NOT EXISTS idx_transactions_date
                    ON ledger_transactions(accounting_date, state);
                CREATE INDEX IF NOT EXISTS idx_sessions_user
                    ON sessions(user_id, revoked_at);
                CREATE INDEX IF NOT EXISTS idx_jobs_due
                    ON scheduled_jobs(state, next_run_at);
                """
            )
            for code, (category, name) in SYSTEM_ACCOUNTS.items():
                con.execute(
                    "INSERT OR IGNORE INTO chart_accounts(code, category, name) VALUES(?,?,?)",
                    (code, category, name),
                )
            roles = {
                "CLIENT": "Cliente pessoa física",
                "ATTENDANT": "Atendimento sem poder financeiro",
                "MANAGER": "Gerente com aprovação",
                "AUDITOR": "Consulta de auditoria",
                "ADMIN": "Administração técnica",
                "PJ_OWNER": "Proprietário de conta PJ",
                "PJ_OPERATOR": "Operador de conta PJ",
                "PJ_APPROVER": "Aprovador de conta PJ",
            }
            permissions = {
                "ACCOUNT_READ": "Consultar conta",
                "ACCOUNT_TRANSACT": "Movimentar conta",
                "ACCOUNT_MANAGE": "Gerenciar conta",
                "USER_MANAGE": "Gerenciar usuários",
                "ROLE_MANAGE": "Gerenciar papéis",
                "AUDIT_READ": "Consultar auditoria",
                "APPROVE": "Aprovar ações críticas",
                "ADMIN_ADJUST": "Efetuar ajuste contábil",
                "PJ_OPERATE": "Operar conta PJ",
                "PJ_APPROVE": "Aprovar operação PJ",
            }
            for role, description in roles.items():
                con.execute("INSERT OR IGNORE INTO roles VALUES(?,?)", (role, description))
            for permission, description in permissions.items():
                con.execute(
                    "INSERT OR IGNORE INTO permissions VALUES(?,?)",
                    (permission, description),
                )
            grants = {
                "CLIENT": {"ACCOUNT_READ", "ACCOUNT_TRANSACT"},
                "ATTENDANT": {"ACCOUNT_READ"},
                "MANAGER": {"ACCOUNT_READ", "ACCOUNT_MANAGE", "APPROVE"},
                "AUDITOR": {"ACCOUNT_READ", "AUDIT_READ"},
                "ADMIN": {
                    "ACCOUNT_READ",
                    "ACCOUNT_MANAGE",
                    "USER_MANAGE",
                    "ROLE_MANAGE",
                    "AUDIT_READ",
                    "APPROVE",
                    "ADMIN_ADJUST",
                },
                "PJ_OWNER": {
                    "ACCOUNT_READ",
                    "ACCOUNT_TRANSACT",
                    "ACCOUNT_MANAGE",
                    "PJ_OPERATE",
                    "PJ_APPROVE",
                },
                "PJ_OPERATOR": {"ACCOUNT_READ", "PJ_OPERATE"},
                "PJ_APPROVER": {"ACCOUNT_READ", "PJ_APPROVE"},
            }
            for role, role_grants in grants.items():
                for permission in role_grants:
                    con.execute(
                        "INSERT OR IGNORE INTO role_permissions VALUES(?,?)",
                        (role, permission),
                    )
            migration_sql = "bank-core-schema-v1"
            con.execute(
                "INSERT OR IGNORE INTO schema_migrations VALUES(?,?,?)",
                (SCHEMA_VERSION, utcnow(), hashlib.sha256(migration_sql.encode()).hexdigest()),
            )

    def integrity_check(self) -> dict[str, Any]:
        with self.connect() as con:
            integrity = con.execute("PRAGMA integrity_check").fetchone()[0]
            foreign_keys = [dict(row) for row in con.execute("PRAGMA foreign_key_check")]
            version = con.execute("PRAGMA user_version").fetchone()[0]
        return {
            "ok": integrity == "ok" and not foreign_keys,
            "integrity": integrity,
            "foreign_key_errors": foreign_keys,
            "sqlite_user_version": version,
            "application_schema_version": SCHEMA_VERSION,
        }

    def repair(self) -> dict[str, Any]:
        self.close_pool()
        connection = self._new_connection(pooled=False)
        try:
            connection.execute("REINDEX")
            connection.execute("PRAGMA optimize")
            connection.execute("VACUUM")
        finally:
            connection.close()
        return self.integrity_check()

    def backup(self, destination: str | Path) -> Path:
        destination = Path(destination)
        destination.parent.mkdir(parents=True, exist_ok=True)
        source = self._new_connection(pooled=False)
        target = sqlite3.connect(destination)
        try:
            source.backup(target)
        finally:
            target.close()
            source.close()
        return destination


class LedgerService:
    """Razão de partidas dobradas e saldos de clientes."""

    def __init__(self, database: BankDatabase):
        self.db = database

    def create_account(
        self,
        account_number: str,
        owner_id: str,
        kind: str = "CC",
        initial_balance: Decimal | str | int = 0,
        overdraft_limit: Decimal | str | int = 0,
    ) -> None:
        now = utcnow()
        balance = money_to_cents(initial_balance)
        limit = money_to_cents(overdraft_limit)
        if balance < 0 or limit < 0:
            raise AccountingError("INVALID_BALANCE", "Saldo inicial e limite não podem ser negativos")
        with self.db.transaction() as con:
            con.execute(
                """INSERT INTO customer_accounts(
                    account_number, owner_id, kind, ledger_balance_cents,
                    projected_balance_cents, overdraft_limit_cents,
                    created_at, updated_at
                ) VALUES(?,?,?,?,?,?,?,?)""",
                (account_number, owner_id, kind, 0, 0, limit, now, now),
            )
        if balance:
            self.post(
                "OPENING_BALANCE",
                f"opening:{account_number}",
                "Saldo de abertura",
                [
                    Posting("CASH", debit_cents=balance),
                    Posting(
                        "CUSTOMER_DEPOSITS",
                        credit_cents=balance,
                        customer_account=account_number,
                    ),
                ],
                created_by="SYSTEM",
                balance_deltas={account_number: balance},
            )

    @staticmethod
    def _load_account(con: sqlite3.Connection, account_number: str) -> Account:
        row = con.execute(
            "SELECT * FROM customer_accounts WHERE account_number=?",
            (account_number,),
        ).fetchone()
        if row is None:
            raise AccountingError("ACCOUNT_NOT_FOUND", f"Conta {account_number} não encontrada")
        return Account.from_row(row)

    @staticmethod
    def _load_hold(con: sqlite3.Connection, hold_id: str) -> Hold:
        row = con.execute("SELECT * FROM holds WHERE hold_id=?", (hold_id,)).fetchone()
        if row is None:
            raise AccountingError("HOLD_NOT_ACTIVE", "Reserva inexistente ou inativa")
        hold = Hold.from_row(row)
        if not hold.is_active:
            raise AccountingError("HOLD_NOT_ACTIVE", "Reserva inexistente ou inativa")
        return hold

    def load_account(self, account_number: str) -> Account:
        """Entidade Conta. Prefira este método a ``account()`` em código novo."""
        with self.db.connect() as con:
            return self._load_account(con, account_number)

    def account(self, account_number: str) -> dict[str, Any]:
        """Projeção em dicionário — mantida para CLI, GUI e testes existentes."""
        return self.load_account(account_number).as_dict()

    def post(
        self,
        kind: str,
        idempotency_key: str,
        description: str,
        postings: Sequence[Posting],
        *,
        created_by: str | None = None,
        balance_deltas: dict[str, int] | None = None,
        settlement_at: str | None = None,
        metadata: dict[str, Any] | None = None,
        original_transaction_id: str | None = None,
    ) -> str:
        if not postings:
            raise AccountingError("EMPTY_TRANSACTION", "Transação sem lançamentos")
        for posting in postings:
            posting.validate()
        debits = sum(item.debit_cents for item in postings)
        credits = sum(item.credit_cents for item in postings)
        if debits != credits:
            raise AccountingError(
                "UNBALANCED_TRANSACTION",
                f"Débitos ({debits}) diferentes dos créditos ({credits})",
            )
        now = utcnow()
        transaction_id = str(uuid.uuid4())
        balance_deltas = balance_deltas or {}
        with (
            TRACER.start("ledger.post", kind=kind, postings=len(postings)),
            self.db.transaction() as con,
        ):
            existing = con.execute(
                "SELECT transaction_id FROM ledger_transactions WHERE idempotency_key=?",
                (idempotency_key,),
            ).fetchone()
            if existing:
                return str(existing["transaction_id"])
            for account_number, delta in balance_deltas.items():
                self._load_account(con, account_number).ensure_can_apply(delta)
            state = "PENDING" if settlement_at else "SETTLED"
            con.execute(
                """INSERT INTO ledger_transactions(
                    transaction_id,idempotency_key,kind,state,description,
                    effective_at,accounting_date,settlement_at,
                    original_transaction_id,metadata,created_by,created_at
                ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    transaction_id,
                    idempotency_key,
                    kind,
                    state,
                    description,
                    now,
                    now[:10],
                    settlement_at,
                    original_transaction_id,
                    json.dumps(metadata or {}, sort_keys=True),
                    created_by,
                    now,
                ),
            )
            for sequence, posting in enumerate(postings, 1):
                con.execute(
                    """INSERT INTO ledger_entries VALUES(?,?,?,?,?,?,?,?,?)""",
                    (
                        str(uuid.uuid4()),
                        transaction_id,
                        sequence,
                        posting.account_code,
                        posting.customer_account,
                        posting.debit_cents,
                        posting.credit_cents,
                        posting.memo,
                        now,
                    ),
                )
            if state == "SETTLED":
                for account_number, delta in balance_deltas.items():
                    self._apply_balance_delta(con, transaction_id, account_number, delta, now)
            else:
                for account_number, delta in balance_deltas.items():
                    con.execute(
                        """UPDATE customer_accounts
                           SET projected_balance_cents=projected_balance_cents+?,
                               version=version+1,updated_at=?
                           WHERE account_number=?""",
                        (delta, now, account_number),
                    )
        METRICS.increment("ledger_transactions_total", kind=kind, state=state)
        METRICS.observe("ledger_transaction_amount_cents", debits, kind=kind)
        LOGGER.info(
            "ledger.posted",
            extra={
                "transaction_id": transaction_id,
                "kind": kind,
                "state": state,
                "amount_cents": debits,
                "postings": len(postings),
            },
        )
        return transaction_id

    def _apply_balance_delta(
        self,
        con: sqlite3.Connection,
        transaction_id: str,
        account_number: str,
        delta: int,
        now: str,
        update_projected: bool = True,
    ) -> None:
        account = con.execute(
            "SELECT * FROM customer_accounts WHERE account_number=?",
            (account_number,),
        ).fetchone()
        previous = int(account["ledger_balance_cents"])
        resulting = previous + delta
        previous_event = con.execute(
            """SELECT event_hash FROM balance_events
               WHERE account_number=? ORDER BY created_at DESC, event_id DESC LIMIT 1""",
            (account_number,),
        ).fetchone()
        previous_hash = previous_event["event_hash"] if previous_event else "GENESIS"
        payload = f"{previous_hash}|{transaction_id}|{account_number}|{previous}|{delta}|{resulting}|{now}"
        event_hash = hashlib.sha256(payload.encode()).hexdigest()
        if update_projected:
            con.execute(
                """UPDATE customer_accounts
                   SET ledger_balance_cents=?, projected_balance_cents=
                       projected_balance_cents+?, version=version+1, updated_at=?
                   WHERE account_number=?""",
                (resulting, delta, now, account_number),
            )
        else:
            con.execute(
                """UPDATE customer_accounts
                   SET ledger_balance_cents=?,version=version+1,updated_at=?
                   WHERE account_number=?""",
                (resulting, now, account_number),
            )
        con.execute(
            "INSERT INTO balance_events VALUES(?,?,?,?,?,?,?,?,?)",
            (
                str(uuid.uuid4()),
                transaction_id,
                account_number,
                previous,
                delta,
                resulting,
                event_hash,
                previous_hash,
                now,
            ),
        )

    def transfer(
        self,
        origin: str,
        destination: str,
        amount: Decimal | str | int,
        idempotency_key: str,
        *,
        kind: str = "TRANSFER",
        description: str = "Transferência",
        created_by: str | None = None,
        fee: Decimal | str | int = 0,
    ) -> str:
        value = money_to_cents(amount)
        fee_cents = money_to_cents(fee)
        if value <= 0 or fee_cents < 0 or origin == destination:
            raise AccountingError("INVALID_TRANSFER", "Transferência inválida")
        postings = [
            Posting("CUSTOMER_DEPOSITS", debit_cents=value, customer_account=origin),
            Posting("CUSTOMER_DEPOSITS", credit_cents=value, customer_account=destination),
        ]
        deltas = {origin: -(value + fee_cents), destination: value}
        if fee_cents:
            postings.extend(
                [
                    Posting("CUSTOMER_DEPOSITS", debit_cents=fee_cents, customer_account=origin),
                    Posting("FEE_REVENUE", credit_cents=fee_cents),
                ]
            )
        return self.post(
            kind,
            idempotency_key,
            description,
            postings,
            created_by=created_by,
            balance_deltas=deltas,
            metadata={"origin": origin, "destination": destination},
        )

    def external_debit(
        self,
        account_number: str,
        amount: Decimal | str | int,
        idempotency_key: str,
        kind: str,
        description: str,
        *,
        destination_account: str = "SETTLEMENT",
        created_by: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> str:
        value = money_to_cents(amount)
        if value <= 0:
            raise AccountingError("INVALID_AMOUNT", "Valor deve ser positivo")
        return self.post(
            kind,
            idempotency_key,
            description,
            [
                Posting("CUSTOMER_DEPOSITS", debit_cents=value, customer_account=account_number),
                Posting(destination_account, credit_cents=value),
            ],
            created_by=created_by,
            balance_deltas={account_number: -value},
            metadata=metadata,
        )

    def external_credit(
        self,
        account_number: str,
        amount: Decimal | str | int,
        idempotency_key: str,
        kind: str,
        description: str,
        *,
        source_account: str = "SETTLEMENT",
        created_by: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> str:
        value = money_to_cents(amount)
        if value <= 0:
            raise AccountingError("INVALID_AMOUNT", "Valor deve ser positivo")
        return self.post(
            kind,
            idempotency_key,
            description,
            [
                Posting(source_account, debit_cents=value),
                Posting("CUSTOMER_DEPOSITS", credit_cents=value, customer_account=account_number),
            ],
            created_by=created_by,
            balance_deltas={account_number: value},
            metadata=metadata,
        )

    def create_hold(
        self,
        account_number: str,
        amount: Decimal | str | int,
        reason: str,
        expires_at: str | None = None,
    ) -> str:
        value = money_to_cents(amount)
        if value <= 0:
            raise AccountingError("INVALID_AMOUNT", "Reserva deve ser positiva")
        hold_id = str(uuid.uuid4())
        now = utcnow()
        with self.db.transaction() as con:
            self._load_account(con, account_number).ensure_can_hold(value)
            con.execute(
                "UPDATE customer_accounts SET blocked_balance_cents=blocked_balance_cents+?, updated_at=? WHERE account_number=?",
                (value, now, account_number),
            )
            con.execute(
                "INSERT INTO holds VALUES(?,?,?,?,?,?,?,?,?,?)",
                (hold_id, account_number, value, 0, "ACTIVE", reason, expires_at, None, now, now),
            )
        return hold_id

    def release_hold(self, hold_id: str) -> None:
        now = utcnow()
        with self.db.transaction() as con:
            hold = self._load_hold(con, hold_id)
            con.execute(
                "UPDATE customer_accounts SET blocked_balance_cents=blocked_balance_cents-?, updated_at=? WHERE account_number=?",
                (hold.remaining_cents, now, hold.account_number),
            )
            con.execute(
                "UPDATE holds SET state='RELEASED', updated_at=? WHERE hold_id=?",
                (now, hold_id),
            )

    def capture_hold(
        self,
        hold_id: str,
        idempotency_key: str,
        amount: Decimal | str | int | None = None,
    ) -> str:
        now = utcnow()
        with self.db.transaction() as con:
            existing = con.execute(
                "SELECT transaction_id FROM ledger_transactions WHERE idempotency_key=?",
                (idempotency_key,),
            ).fetchone()
            if existing:
                return str(existing["transaction_id"])
            hold = self._load_hold(con, hold_id)
            value = hold.remaining_cents if amount is None else money_to_cents(amount)
            hold.ensure_capturable(value)
            account = self._load_account(con, hold.account_number)
            if account.available_for_capture_cents(hold.remaining_cents) < value:
                raise AccountingError("INSUFFICIENT_FUNDS", "Saldo da reserva indisponível")
            transaction_id = str(uuid.uuid4())
            con.execute(
                """INSERT INTO ledger_transactions(
                    transaction_id,idempotency_key,kind,state,description,
                    effective_at,accounting_date,settlement_at,
                    original_transaction_id,metadata,created_by,created_at
                ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    transaction_id,
                    idempotency_key,
                    "HOLD_CAPTURE",
                    "SETTLED",
                    f"Captura de reserva: {hold.reason}",
                    now,
                    now[:10],
                    now,
                    None,
                    json.dumps({"hold_id": hold_id}),
                    None,
                    now,
                ),
            )
            con.execute(
                "INSERT INTO ledger_entries VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    str(uuid.uuid4()),
                    transaction_id,
                    1,
                    "CUSTOMER_DEPOSITS",
                    hold.account_number,
                    value,
                    0,
                    f"Captura da reserva {hold_id}",
                    now,
                ),
            )
            con.execute(
                "INSERT INTO ledger_entries VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    str(uuid.uuid4()),
                    transaction_id,
                    2,
                    "SETTLEMENT",
                    None,
                    0,
                    value,
                    f"Captura da reserva {hold_id}",
                    now,
                ),
            )
            self._apply_balance_delta(con, transaction_id, hold.account_number, -value, now)
            con.execute(
                "UPDATE customer_accounts SET blocked_balance_cents=blocked_balance_cents-?, updated_at=? WHERE account_number=?",
                (value, now, hold.account_number),
            )
            new_captured = hold.captured_cents + value
            state = hold.state_after_capturing(value)
            con.execute(
                "UPDATE holds SET captured_cents=?, state=?, transaction_id=?, updated_at=? WHERE hold_id=?",
                (new_captured, state, transaction_id, now, hold_id),
            )
        return transaction_id

    def reverse(
        self,
        transaction_id: str,
        idempotency_key: str,
        amount: Decimal | str | int | None = None,
        *,
        created_by: str | None = None,
    ) -> str:
        with self.db.connect() as con:
            transaction = con.execute(
                "SELECT * FROM ledger_transactions WHERE transaction_id=?",
                (transaction_id,),
            ).fetchone()
            entries = con.execute(
                "SELECT * FROM ledger_entries WHERE transaction_id=? ORDER BY sequence",
                (transaction_id,),
            ).fetchall()
            previous_reversals = con.execute(
                """SELECT COALESCE(SUM(CAST(json_extract(metadata,'$.reversed_cents') AS INTEGER)),0)
                   FROM ledger_transactions
                   WHERE original_transaction_id=? AND state='SETTLED'""",
                (transaction_id,),
            ).fetchone()[0]
        if transaction is None or transaction["state"] != "SETTLED":
            raise AccountingError("NOT_REVERSIBLE", "Transação não pode ser estornada")
        total = sum(row["debit_cents"] for row in entries)
        requested = total - previous_reversals if amount is None else money_to_cents(amount)
        if requested <= 0 or requested + previous_reversals > total:
            raise AccountingError("INVALID_REVERSAL", "Valor de estorno inválido")
        ratio = Decimal(requested) / Decimal(total)
        reverse_postings: list[Posting] = []
        remaining = requested
        debit_entries = [row for row in entries if row["debit_cents"]]
        credit_entries = [row for row in entries if row["credit_cents"]]

        def prorate(rows: Sequence[sqlite3.Row], side: str) -> list[Posting]:
            nonlocal remaining
            result: list[Posting] = []
            allocated = 0
            for index, row in enumerate(rows):
                base = row["debit_cents"] or row["credit_cents"]
                part = (
                    requested - allocated
                    if index == len(rows) - 1
                    else int((Decimal(base) * ratio).quantize(Decimal("1"), rounding=ROUND_HALF_EVEN))
                )
                allocated += part
                if part:
                    result.append(
                        Posting(
                            row["account_code"],
                            debit_cents=part if side == "debit" else 0,
                            credit_cents=part if side == "credit" else 0,
                            customer_account=row["customer_account"],
                            memo=f"Estorno de {transaction_id}",
                        )
                    )
            remaining = requested - allocated
            return result

        reverse_postings.extend(prorate(credit_entries, "debit"))
        reverse_postings.extend(prorate(debit_entries, "credit"))
        balance_deltas: dict[str, int] = {}
        for posting in reverse_postings:
            if posting.customer_account:
                delta = posting.credit_cents - posting.debit_cents
                balance_deltas[posting.customer_account] = (
                    balance_deltas.get(posting.customer_account, 0) + delta
                )
        return self.post(
            "REVERSAL",
            idempotency_key,
            f"Estorno de {transaction_id}",
            reverse_postings,
            created_by=created_by,
            balance_deltas=balance_deltas,
            metadata={"reversed_cents": requested},
            original_transaction_id=transaction_id,
        )

    def settle_pending(self, transaction_id: str) -> None:
        now = utcnow()
        with self.db.transaction() as con:
            transaction = con.execute(
                "SELECT * FROM ledger_transactions WHERE transaction_id=?",
                (transaction_id,),
            ).fetchone()
            if transaction is None or transaction["state"] != "PENDING":
                raise AccountingError("NOT_PENDING", "Lançamento não está pendente")
            entries = con.execute(
                "SELECT * FROM ledger_entries WHERE transaction_id=?",
                (transaction_id,),
            ).fetchall()
            deltas: dict[str, int] = {}
            for entry in entries:
                if entry["customer_account"]:
                    deltas[entry["customer_account"]] = (
                        deltas.get(entry["customer_account"], 0)
                        + entry["credit_cents"]
                        - entry["debit_cents"]
                    )
            for account_number, delta in deltas.items():
                self._apply_balance_delta(
                    con,
                    transaction_id,
                    account_number,
                    delta,
                    now,
                    update_projected=False,
                )
            con.execute(
                "UPDATE ledger_transactions SET state='SETTLED', settlement_at=? WHERE transaction_id=?",
                (now, transaction_id),
            )

    def reconcile(self) -> dict[str, Any]:
        discrepancies: list[dict[str, Any]] = []
        with self.db.connect() as con:
            accounts = con.execute("SELECT * FROM customer_accounts").fetchall()
            unbalanced = con.execute(
                """SELECT transaction_id,
                          SUM(debit_cents) AS debits, SUM(credit_cents) AS credits
                   FROM ledger_entries GROUP BY transaction_id
                   HAVING debits <> credits"""
            ).fetchall()
            for account in accounts:
                event_total = con.execute(
                    "SELECT COALESCE(SUM(delta_cents),0) FROM balance_events WHERE account_number=?",
                    (account["account_number"],),
                ).fetchone()[0]
                if event_total != account["ledger_balance_cents"]:
                    discrepancies.append(
                        {
                            "account": account["account_number"],
                            "stored_cents": account["ledger_balance_cents"],
                            "events_cents": event_total,
                        }
                    )
        return {
            "ok": not discrepancies and not unbalanced,
            "account_discrepancies": discrepancies,
            "unbalanced_transactions": [dict(row) for row in unbalanced],
        }

    def close_period(self, period: str, close_type: str, closed_by: str) -> None:
        if close_type not in {"DAILY", "MONTHLY"}:
            raise AccountingError("INVALID_CLOSE", "Fechamento deve ser diário ou mensal")
        with self.db.transaction() as con:
            totals = con.execute(
                """SELECT COALESCE(SUM(debit_cents),0), COALESCE(SUM(credit_cents),0)
                   FROM ledger_entries e JOIN ledger_transactions t USING(transaction_id)
                   WHERE t.accounting_date LIKE ? AND t.state='SETTLED'""",
                (period + "%",),
            ).fetchone()
            if totals[0] != totals[1]:
                raise AccountingError("UNBALANCED_CLOSE", "Balancete não fecha")
            con.execute(
                "INSERT INTO close_periods VALUES(?,?,?,?,?,?)",
                (period, close_type, utcnow(), closed_by, totals[0], totals[1]),
            )


class SecurityService:
    """Credenciais, sessões, TOTP, recuperação, RBAC e auditoria."""

    PASSWORD_PATTERN = re.compile(r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{12,128}$")

    def __init__(self, database: BankDatabase):
        self.db = database
        if PasswordHasher is None:
            raise RuntimeError("argon2-cffi é obrigatório: instale com 'python -m pip install argon2-cffi'")
        self.hasher = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=4, hash_len=32, salt_len=16)
        self._DUMMY_HASH = self.hasher.hash(secrets.token_urlsafe(32))

    def validate_password(self, password: str, username: str = "") -> None:
        if not self.PASSWORD_PATTERN.match(password):
            raise AuthenticationError(
                "WEAK_PASSWORD",
                "Senha deve ter 12-128 caracteres, maiúscula, minúscula, número e símbolo",
            )
        lowered = password.casefold()
        if username and username.casefold() in lowered:
            raise AuthenticationError("WEAK_PASSWORD", "Senha não pode conter o usuário")
        common = {"password", "senha123", "admin123", "qwerty", "123456"}
        if any(item in lowered for item in common):
            raise AuthenticationError("WEAK_PASSWORD", "Senha consta na lista de bloqueio")

    def create_user(
        self,
        username: str,
        password: str,
        *,
        cpf_cnpj: str | None = None,
        roles: Iterable[str] = ("CLIENT",),
        admin_expiry_days: int | None = None,
    ) -> str:
        self.validate_password(password, username)
        user_id = str(uuid.uuid4())
        now = utcnow()
        password_hash = self.hasher.hash(password)
        expires = (
            (datetime.now(UTC) + timedelta(days=admin_expiry_days)).isoformat() if admin_expiry_days else None
        )
        with self.db.transaction() as con:
            con.execute(
                """INSERT INTO users(
                    user_id,username,cpf_cnpj,password_hash,password_changed_at,
                    admin_password_expires_at,created_at,updated_at
                ) VALUES(?,?,?,?,?,?,?,?)""",
                (user_id, username, cpf_cnpj, password_hash, now, expires, now, now),
            )
            for role in roles:
                con.execute("INSERT INTO user_roles VALUES(?,?)", (user_id, role))
        self.audit(user_id, "USER_CREATE", user_id, "SUCCESS", {"username": username})
        return user_id

    def migrate_legacy_credential(
        self,
        username: str,
        legacy_plaintext: str,
        supplied_password: str,
        *,
        cpf_cnpj: str | None = None,
        roles: Iterable[str] = ("CLIENT",),
    ) -> str:
        """Migra no primeiro login e nunca persiste novamente o segredo legado.

        O chamador deve apagar o campo legado somente após o retorno bem-sucedido.
        A comparação em tempo constante reduz vazamento por temporização.
        """
        if not hmac.compare_digest(legacy_plaintext.encode("utf-8"), supplied_password.encode("utf-8")):
            self.audit(None, "LEGACY_MIGRATION", username, "FAILURE", {})
            raise AuthenticationError("INVALID_CREDENTIALS", "Credenciais inválidas")
        user_id = self.create_user(username, supplied_password, cpf_cnpj=cpf_cnpj, roles=roles)
        self.audit(user_id, "LEGACY_MIGRATION", username, "SUCCESS", {})
        return user_id

    def authenticate(
        self,
        username: str,
        password: str,
        *,
        device: str = "CLI",
        ip_address: str | None = None,
        totp_code: str | None = None,
        session_minutes: int = 30,
        idle_minutes: int = 10,
    ) -> dict[str, str]:
        now_dt = datetime.now(UTC)
        with self.db.connect() as con:
            user = con.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()
        if user is None:
            self._dummy_verify(password)
            self.audit(None, "LOGIN", username, "FAILURE", {"reason": "unknown_user"})
            raise AuthenticationError("INVALID_CREDENTIALS", "Credenciais inválidas")
        if not user["active"]:
            raise AuthenticationError("USER_INACTIVE", "Usuário inativo")
        if user["locked_until"] and datetime.fromisoformat(user["locked_until"]) > now_dt:
            raise AuthenticationError("USER_LOCKED", "Usuário temporariamente bloqueado")
        try:
            verified = self.hasher.verify(user["password_hash"], password)
        except (VerifyMismatchError, InvalidHashError):
            verified = False
        if not verified:
            self._register_failed_attempt(user, now_dt, username, "password")
            raise AuthenticationError("INVALID_CREDENTIALS", "Credenciais inválidas")
        if (
            user["admin_password_expires_at"]
            and datetime.fromisoformat(user["admin_password_expires_at"]) <= now_dt
        ):
            raise AuthenticationError("PASSWORD_EXPIRED", "Senha administrativa expirada")
        if user["totp_enabled"]:
            second_factor_ok = bool(totp_code) and (
                self._consume_totp(user["user_id"], user["totp_secret"], totp_code)
                or self.use_recovery_code(user["user_id"], totp_code)
            )
            if not second_factor_ok:
                self._register_failed_attempt(user, now_dt, username, "totp")
                raise AuthenticationError("TOTP_REQUIRED", "Segundo fator inválido ou ausente")
        if self.hasher.check_needs_rehash(user["password_hash"]):
            with self.db.transaction() as con:
                con.execute(
                    "UPDATE users SET password_hash=?,updated_at=? WHERE user_id=?",
                    (self.hasher.hash(password), utcnow(), user["user_id"]),
                )
        token = secrets.token_urlsafe(48)
        refresh = secrets.token_urlsafe(64)
        session_id = str(uuid.uuid4())
        now = utcnow()
        expires = (now_dt + timedelta(minutes=session_minutes)).isoformat()
        idle_expires = (now_dt + timedelta(minutes=idle_minutes)).isoformat()
        with self.db.transaction() as con:
            con.execute(
                "UPDATE users SET failed_attempts=0,locked_until=NULL,updated_at=? WHERE user_id=?",
                (now, user["user_id"]),
            )
            con.execute(
                "INSERT INTO sessions VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                (
                    session_id,
                    user["user_id"],
                    hash_token(token),
                    hash_token(refresh),
                    device,
                    ip_address,
                    now,
                    now,
                    expires,
                    idle_expires,
                    None,
                ),
            )
        self.audit(user["user_id"], "LOGIN", session_id, "SUCCESS", {"device": device})
        return {"session_id": session_id, "token": token, "refresh_token": refresh}

    def _dummy_verify(self, password: str) -> None:
        """Consome o mesmo custo de Argon2 de uma verificação real."""
        try:
            self.hasher.verify(self._DUMMY_HASH, password)
        except (VerifyMismatchError, InvalidHashError):
            pass

    def _register_failed_attempt(
        self, user: sqlite3.Row, now_dt: datetime, username: str, factor: str
    ) -> None:
        """Incrementa o contador e aplica bloqueio exponencial após 3 falhas."""
        attempts = user["failed_attempts"] + 1
        delay = min(3600, 2 ** min(attempts, 11))
        locked_until = (now_dt + timedelta(seconds=delay)).isoformat() if attempts >= 3 else None
        with self.db.transaction() as con:
            con.execute(
                "UPDATE users SET failed_attempts=?,locked_until=?,updated_at=? WHERE user_id=?",
                (attempts, locked_until, utcnow(), user["user_id"]),
            )
        self.audit(
            user["user_id"],
            "LOGIN",
            username,
            "FAILURE",
            {"attempt": attempts, "factor": factor},
        )

    def require_session(self, token: str, idle_minutes: int = 10) -> sqlite3.Row:
        now_dt = datetime.now(UTC)
        with self.db.transaction() as con:
            session = con.execute(
                """SELECT s.*,u.active FROM sessions s JOIN users u USING(user_id)
                   WHERE token_hash=?""",
                (hash_token(token),),
            ).fetchone()
            if (
                session is None
                or session["revoked_at"]
                or not session["active"]
                or datetime.fromisoformat(session["expires_at"]) <= now_dt
                or datetime.fromisoformat(session["idle_expires_at"]) <= now_dt
            ):
                raise AuthenticationError("SESSION_EXPIRED", "Sessão inválida ou expirada")
            now = utcnow()
            idle = (now_dt + timedelta(minutes=idle_minutes)).isoformat()
            con.execute(
                "UPDATE sessions SET last_seen_at=?,idle_expires_at=? WHERE session_id=?",
                (now, idle, session["session_id"]),
            )
        return session

    ABSOLUTE_SESSION_HOURS = 12

    def refresh_session(self, refresh_token: str, minutes: int = 30) -> dict[str, str]:
        with self.db.transaction() as con:
            session = con.execute(
                """SELECT s.*,u.active FROM sessions s JOIN users u USING(user_id)
                   WHERE s.refresh_hash=? AND s.revoked_at IS NULL""",
                (hash_token(refresh_token),),
            ).fetchone()
            now_dt = datetime.now(UTC)
            if (
                session is None
                or not session["active"]
                or (
                    datetime.fromisoformat(session["created_at"])
                    + timedelta(hours=self.ABSOLUTE_SESSION_HOURS)
                    <= now_dt
                )
            ):
                raise AuthenticationError("INVALID_REFRESH", "Refresh token inválido")
            new_token = secrets.token_urlsafe(48)
            new_refresh = secrets.token_urlsafe(64)
            con.execute(
                """UPDATE sessions SET token_hash=?,refresh_hash=?,last_seen_at=?,
                   expires_at=?,idle_expires_at=? WHERE session_id=?""",
                (
                    hash_token(new_token),
                    hash_token(new_refresh),
                    utcnow(),
                    (now_dt + timedelta(minutes=minutes)).isoformat(),
                    (now_dt + timedelta(minutes=10)).isoformat(),
                    session["session_id"],
                ),
            )
        return {"token": new_token, "refresh_token": new_refresh}

    def revoke_session(self, session_id: str, actor_id: str | None = None) -> None:
        with self.db.transaction() as con:
            con.execute(
                "UPDATE sessions SET revoked_at=? WHERE session_id=? AND revoked_at IS NULL",
                (utcnow(), session_id),
            )
        self.audit(actor_id, "SESSION_REVOKE", session_id, "SUCCESS", {})

    def revoke_all_sessions(self, user_id: str, actor_id: str | None = None) -> None:
        with self.db.transaction() as con:
            con.execute(
                "UPDATE sessions SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL",
                (utcnow(), user_id),
            )
        self.audit(actor_id or user_id, "SESSION_REVOKE_ALL", user_id, "SUCCESS", {})

    def list_sessions(self, user_id: str) -> list[dict[str, Any]]:
        with self.db.connect() as con:
            return [
                dict(row)
                for row in con.execute(
                    """SELECT session_id,device,ip_address,created_at,last_seen_at,
                              expires_at,idle_expires_at,revoked_at
                       FROM sessions WHERE user_id=? ORDER BY created_at DESC""",
                    (user_id,),
                )
            ]

    def change_password(self, user_id: str, current: str, new: str) -> None:
        with self.db.connect() as con:
            user = con.execute("SELECT * FROM users WHERE user_id=?", (user_id,)).fetchone()
            history = con.execute(
                "SELECT password_hash FROM password_history WHERE user_id=? ORDER BY created_at DESC LIMIT 5",
                (user_id,),
            ).fetchall()
        try:
            current_valid = bool(user is not None and self.hasher.verify(user["password_hash"], current))
        except (VerifyMismatchError, InvalidHashError):
            current_valid = False
        if not current_valid:
            raise AuthenticationError("INVALID_CREDENTIALS", "Senha atual inválida")
        self.validate_password(new, user["username"])
        for old_hash in [user["password_hash"], *(row["password_hash"] for row in history)]:
            try:
                if self.hasher.verify(old_hash, new):
                    raise AuthenticationError("PASSWORD_REUSED", "Senha já utilizada")
            except VerifyMismatchError:
                pass
        now = utcnow()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO password_history VALUES(?,?,?,?)",
                (str(uuid.uuid4()), user_id, user["password_hash"], now),
            )
            con.execute(
                """UPDATE users SET password_hash=?,password_changed_at=?,
                   failed_attempts=0,locked_until=NULL,updated_at=? WHERE user_id=?""",
                (self.hasher.hash(new), now, now, user_id),
            )
            con.execute(
                "UPDATE sessions SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL",
                (now, user_id),
            )
        self.audit(user_id, "PASSWORD_CHANGE", user_id, "SUCCESS", {})

    def enable_totp(self, user_id: str) -> dict[str, Any]:
        secret = base64.b32encode(secrets.token_bytes(20)).decode().rstrip("=")
        codes = [secrets.token_hex(5).upper() for _ in range(10)]
        now = utcnow()
        with self.db.transaction() as con:
            con.execute(
                "UPDATE users SET totp_secret=?,totp_enabled=1,updated_at=? WHERE user_id=?",
                (secret, now, user_id),
            )
            con.execute("DELETE FROM recovery_codes WHERE user_id=?", (user_id,))
            for code in codes:
                con.execute(
                    "INSERT INTO recovery_codes VALUES(?,?,?,?,?)",
                    (str(uuid.uuid4()), user_id, hash_token(code), None, now),
                )
        self.audit(user_id, "TOTP_ENABLE", user_id, "SUCCESS", {})
        return {"secret": secret, "recovery_codes": codes}

    @staticmethod
    def totp(secret: str, at: int | None = None, step: int = 30) -> str:
        at = int(time.time()) if at is None else at
        padding = "=" * ((8 - len(secret) % 8) % 8)
        key = base64.b32decode(secret + padding, casefold=True)
        counter = struct.pack(">Q", at // step)
        digest = hmac.new(key, counter, hashlib.sha1).digest()
        offset = digest[-1] & 0x0F
        code = (struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF) % 1_000_000
        return f"{code:06d}"

    @classmethod
    def verify_totp(cls, secret: str, code: str, window: int = 1) -> bool:
        now = int(time.time())
        return any(
            hmac.compare_digest(cls.totp(secret, now + offset * 30), str(code).zfill(6))
            for offset in range(-window, window + 1)
        )

    def _consume_totp(self, user_id: str, secret: str, code: str) -> bool:
        """Valida o TOTP e o invalida imediatamente.

        A janela de ±1 passo aceita o mesmo código por até 90 s. Sem consumo,
        um código observado (ombro, phishing, log) continua válido nesse
        intervalo — replay clássico. O registro do uso fecha a janela.
        """
        if not self.verify_totp(secret, code):
            return False
        normalized = str(code).zfill(6)
        with self.db.transaction() as con:
            already = con.execute(
                "SELECT 1 FROM used_totp_codes WHERE user_id=? AND code_hash=?",
                (user_id, hash_token(normalized)),
            ).fetchone()
            if already:
                LOGGER.warning("auth.totp_replay_blocked", extra={"actor_id": user_id})
                return False
            con.execute(
                "INSERT INTO used_totp_codes VALUES(?,?,?)",
                (user_id, hash_token(normalized), utcnow()),
            )
            con.execute(
                "DELETE FROM used_totp_codes WHERE created_at<?",
                ((datetime.now(UTC) - timedelta(minutes=5)).isoformat(),),
            )
        return True

    def use_recovery_code(self, user_id: str, code: str) -> bool:
        with self.db.transaction() as con:
            row = con.execute(
                "SELECT * FROM recovery_codes WHERE user_id=? AND code_hash=? AND used_at IS NULL",
                (user_id, hash_token(code.upper())),
            ).fetchone()
            if row is None:
                return False
            con.execute(
                "UPDATE recovery_codes SET used_at=? WHERE code_id=?",
                (utcnow(), row["code_id"]),
            )
        self.audit(user_id, "RECOVERY_CODE_USED", user_id, "SUCCESS", {})
        return True

    RESET_REQUESTS_PER_HOUR = 5

    def request_password_reset(
        self, username: str, recipient: str, channel: str = "EMAIL", minutes: int = 15
    ) -> str | None:
        """Emite um token de redefinição e o entrega pelo outbox.

        O token retornado é uma conveniência de teste e de adaptadores locais —
        o canal de verdade é o outbox. Em produção, descarte o retorno: quem o
        repassa adiante transforma a redefinição em bypass de autenticação.
        """
        with self.db.connect() as con:
            user = con.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()
        if user is None:
            return None
        window_start = (datetime.now(UTC) - timedelta(hours=1)).isoformat()
        with self.db.connect() as con:
            recent = con.execute(
                "SELECT COUNT(*) FROM reset_tokens WHERE user_id=? AND created_at>=?",
                (user["user_id"], window_start),
            ).fetchone()[0]
        if recent >= self.RESET_REQUESTS_PER_HOUR:
            self.audit(
                user["user_id"],
                "PASSWORD_RESET_REQUEST",
                username,
                "DENIED",
                {"reason": "rate_limited"},
            )
            raise AuthenticationError(
                "RESET_RATE_LIMITED", "Muitas solicitações de redefinição; tente mais tarde"
            )
        token = secrets.token_urlsafe(40)
        now = utcnow()
        expires = (datetime.now(UTC) + timedelta(minutes=minutes)).isoformat()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO reset_tokens VALUES(?,?,?,?,?,?)",
                (str(uuid.uuid4()), user["user_id"], hash_token(token), expires, None, now),
            )
            con.execute(
                "INSERT INTO outbox VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    str(uuid.uuid4()),
                    channel,
                    recipient,
                    "PASSWORD_RESET",
                    json.dumps({"token": token, "expires_at": expires}),
                    "PENDING",
                    0,
                    now,
                    None,
                ),
            )
        self.audit(user["user_id"], "PASSWORD_RESET_REQUEST", username, "SUCCESS", {})
        return token

    def complete_password_reset(self, token: str, new_password: str) -> None:
        now_dt = datetime.now(UTC)
        with self.db.connect() as con:
            reset = con.execute(
                "SELECT r.*,u.username FROM reset_tokens r JOIN users u USING(user_id) WHERE token_hash=?",
                (hash_token(token),),
            ).fetchone()
        if reset is None or reset["used_at"] or datetime.fromisoformat(reset["expires_at"]) <= now_dt:
            raise AuthenticationError("INVALID_RESET", "Token inválido ou expirado")
        self.validate_password(new_password, reset["username"])
        now = utcnow()
        with self.db.transaction() as con:
            con.execute(
                "UPDATE reset_tokens SET used_at=? WHERE token_id=?",
                (now, reset["token_id"]),
            )
            con.execute(
                "UPDATE users SET password_hash=?,password_changed_at=?,updated_at=? WHERE user_id=?",
                (self.hasher.hash(new_password), now, now, reset["user_id"]),
            )
            con.execute(
                "UPDATE sessions SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL",
                (now, reset["user_id"]),
            )
        self.audit(reset["user_id"], "PASSWORD_RESET", reset["user_id"], "SUCCESS", {})

    def has_permission(self, user_id: str, permission: str) -> bool:
        with self.db.connect() as con:
            row = con.execute(
                """SELECT 1 FROM user_roles ur JOIN role_permissions rp USING(role)
                   WHERE ur.user_id=? AND rp.permission=? LIMIT 1""",
                (user_id, permission),
            ).fetchone()
        return row is not None

    def require_permission(self, user_id: str, permission: str) -> None:
        if not self.has_permission(user_id, permission):
            self.audit(user_id, "AUTHORIZE", permission, "DENIED", {})
            raise AuthorizationError("FORBIDDEN", f"Permissão necessária: {permission}")

    def grant_role(self, actor_id: str, user_id: str, role: str) -> None:
        self.require_permission(actor_id, "ROLE_MANAGE")
        with self.db.transaction() as con:
            con.execute("INSERT OR IGNORE INTO user_roles VALUES(?,?)", (user_id, role))
        self.audit(actor_id, "ROLE_GRANT", user_id, "SUCCESS", {"role": role})

    def grant_account_access(
        self,
        actor_id: str,
        user_id: str,
        account_number: str,
        relationship: str,
        permissions: Iterable[str],
        valid_until: str | None = None,
    ) -> None:
        self.require_permission(actor_id, "ACCOUNT_MANAGE")
        values = sorted(set(permissions))
        with self.db.transaction() as con:
            con.execute(
                """INSERT OR REPLACE INTO account_access VALUES(?,?,?,?,?,?)""",
                (
                    user_id,
                    account_number,
                    relationship,
                    utcnow(),
                    valid_until,
                    json.dumps(values),
                ),
            )
        self.audit(
            actor_id,
            "ACCOUNT_ACCESS_GRANT",
            account_number,
            "SUCCESS",
            {"user_id": user_id, "relationship": relationship, "permissions": values},
        )

    def require_account_access(self, user_id: str, account_number: str, permission: str) -> None:
        now = utcnow()
        with self.db.connect() as con:
            rows = con.execute(
                """SELECT * FROM account_access
                   WHERE user_id=? AND account_number=? AND valid_from<=?
                     AND (valid_until IS NULL OR valid_until>?)""",
                (user_id, account_number, now, now),
            ).fetchall()
        if not any(permission in json.loads(row["permissions"]) for row in rows):
            raise AuthorizationError("ACCOUNT_FORBIDDEN", "Usuário não autorizado nesta conta")

    def request_approval(
        self, action: str, resource_id: str, payload: dict[str, Any], requested_by: str, minutes: int = 30
    ) -> str:
        if action not in SENSITIVE_ACTIONS:
            raise AuthorizationError("INVALID_APPROVAL", "Ação não requer dupla autorização")
        approval_id = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO approvals VALUES(?,?,?,?,?,?,?,?,?,?)",
                (
                    approval_id,
                    action,
                    resource_id,
                    json.dumps(payload, sort_keys=True),
                    requested_by,
                    None,
                    "PENDING",
                    (datetime.now(UTC) + timedelta(minutes=minutes)).isoformat(),
                    utcnow(),
                    None,
                ),
            )
        self.audit(requested_by, "APPROVAL_REQUEST", approval_id, "SUCCESS", {"action": action})
        return approval_id

    def approve(self, approval_id: str, approved_by: str) -> dict[str, Any]:
        self.require_permission(approved_by, "APPROVE")
        with self.db.transaction() as con:
            row = con.execute("SELECT * FROM approvals WHERE approval_id=?", (approval_id,)).fetchone()
            if row is None or row["state"] != "PENDING":
                raise AuthorizationError("APPROVAL_NOT_PENDING", "Aprovação não está pendente")
            if row["requested_by"] == approved_by:
                raise AuthorizationError("FOUR_EYES", "Solicitante não pode aprovar a própria ação")
            if datetime.fromisoformat(row["expires_at"]) <= datetime.now(UTC):
                con.execute(
                    "UPDATE approvals SET state='EXPIRED',decided_at=? WHERE approval_id=?",
                    (utcnow(), approval_id),
                )
                raise AuthorizationError("APPROVAL_EXPIRED", "Aprovação expirada")
            con.execute(
                """UPDATE approvals SET state='APPROVED',approved_by=?,decided_at=?
                   WHERE approval_id=?""",
                (approved_by, utcnow(), approval_id),
            )
        self.audit(approved_by, "APPROVAL_APPROVE", approval_id, "SUCCESS", {})
        result = dict(row)
        result["payload"] = json.loads(result["payload"])
        result["state"] = "APPROVED"
        result["approved_by"] = approved_by
        return result

    def audit(
        self,
        actor_id: str | None,
        action: str,
        resource: str,
        result: str,
        details: dict[str, Any],
    ) -> str:
        event_id = str(uuid.uuid4())
        now = utcnow()
        details_json = json.dumps(details, sort_keys=True, ensure_ascii=False)
        with self.db.transaction() as con:
            previous = con.execute(
                "SELECT event_hash FROM audit_events ORDER BY sequence DESC LIMIT 1"
            ).fetchone()
            previous_hash = previous["event_hash"] if previous else "GENESIS"
            payload = (
                f"{previous_hash}|{event_id}|{actor_id}|{action}|{resource}|{result}|{details_json}|{now}"
            )
            event_hash = hashlib.sha256(payload.encode()).hexdigest()
            con.execute(
                """INSERT INTO audit_events(
                    event_id,actor_id,action,resource,result,details,
                    previous_hash,event_hash,created_at
                ) VALUES(?,?,?,?,?,?,?,?,?)""",
                (
                    event_id,
                    actor_id,
                    action,
                    resource,
                    result,
                    details_json,
                    previous_hash,
                    event_hash,
                    now,
                ),
            )
        METRICS.increment("audit_events_total", action=action, result=result)
        level = LOGGER.warning if result in {"FAILURE", "DENIED"} else LOGGER.info
        level(
            "audit.event",
            extra={
                "event_id": event_id,
                "actor_id": actor_id,
                "action": action,
                "resource": resource,
                "result": result,
            },
        )
        return event_id

    def verify_audit_chain(self) -> bool:
        previous_hash = "GENESIS"
        with self.db.connect() as con:
            rows = con.execute("SELECT * FROM audit_events ORDER BY sequence").fetchall()
        for row in rows:
            payload = (
                f"{previous_hash}|{row['event_id']}|{row['actor_id']}|{row['action']}|"
                f"{row['resource']}|{row['result']}|{row['details']}|{row['created_at']}"
            )
            expected = hashlib.sha256(payload.encode()).hexdigest()
            if row["previous_hash"] != previous_hash or not hmac.compare_digest(expected, row["event_hash"]):
                return False
            previous_hash = row["event_hash"]
        return True


class ModuleIntegrationService:
    """Liquida produtos satélite no razão e registra eventos/notificações."""

    DEBITS = {
        "DONATION",
        "RECURRING_DONATION",
        "AUTOMATIC_DEBIT",
        "CHEQUE_CLEARING",
        "INSURANCE_PREMIUM",
        "CONSORTIUM_INSTALLMENT",
        "CONSORTIUM_BID",
        "PENSION_CONTRIBUTION",
        "CAPITALIZATION_INSTALLMENT",
        "SWIFT_TRANSFER",
        "INVESTMENT_APPLICATION",
        "BOLETO_PAYMENT",
        "CARD_BILL_PAYMENT",
        "LOAN_INSTALLMENT",
        "OVERDRAFT_DRAW",
        "PAYROLL_LOAN_INSTALLMENT",
    }
    CREDITS = {
        "CASHBACK",
        "CHEQUE_RETURN",
        "INSURANCE_CLAIM",
        "PENSION_REDEMPTION",
        "CAPITALIZATION_REDEMPTION",
        "CAPITALIZATION_PRIZE",
        "FGTS_WITHDRAWAL",
        "FGTS_ADVANCE",
        "COLLECTION_SETTLEMENT",
        "PAYROLL_LOAN",
        "INVESTMENT_REDEMPTION",
        "LOYALTY_REWARD",
    }

    def __init__(
        self, database: BankDatabase, ledger: LedgerService, security: SecurityService | None = None
    ):
        self.db = database
        self.ledger = ledger
        self.security = security

    def settle(
        self,
        module: str,
        kind: str,
        account_number: str,
        amount: Decimal | str | int,
        idempotency_key: str,
        *,
        actor_id: str | None = None,
        payload: dict[str, Any] | None = None,
    ) -> str:
        if kind not in SATELLITE_KINDS:
            raise BankError("UNKNOWN_MODULE_EVENT", f"Evento satélite desconhecido: {kind}")
        if actor_id and self.security:
            self.security.require_account_access(actor_id, account_number, "TRANSACT")
        value = money_to_cents(amount)
        metadata = {"module": module, **(payload or {})}
        if kind in self.DEBITS:
            destination = (
                "INVESTMENT_CUSTODY"
                if kind == "INVESTMENT_APPLICATION"
                else "INSURANCE_PAYABLE"
                if kind == "INSURANCE_PREMIUM"
                else "SETTLEMENT"
            )
            transaction_id = self.ledger.external_debit(
                account_number,
                value,
                idempotency_key,
                kind,
                f"{module}: {kind}",
                destination_account=destination,
                created_by=actor_id,
                metadata=metadata,
            )
        elif kind in self.CREDITS:
            source = (
                "INVESTMENT_CUSTODY"
                if kind == "INVESTMENT_REDEMPTION"
                else "INSURANCE_PAYABLE"
                if kind == "INSURANCE_CLAIM"
                else "SETTLEMENT"
            )
            transaction_id = self.ledger.external_credit(
                account_number,
                value,
                idempotency_key,
                kind,
                f"{module}: {kind}",
                source_account=source,
                created_by=actor_id,
                metadata=metadata,
            )
        elif kind == "SAVINGS_BOX":
            action = (payload or {}).get("action")
            if action == "DEPOSIT":
                transaction_id = self.ledger.external_debit(
                    account_number,
                    value,
                    idempotency_key,
                    kind,
                    "Aporte em caixinha",
                    destination_account="BLOCKED_FUNDS",
                    created_by=actor_id,
                    metadata=metadata,
                )
            elif action == "WITHDRAW":
                transaction_id = self.ledger.external_credit(
                    account_number,
                    value,
                    idempotency_key,
                    kind,
                    "Resgate de caixinha",
                    source_account="BLOCKED_FUNDS",
                    created_by=actor_id,
                    metadata=metadata,
                )
            else:
                raise BankError("INVALID_SAVINGS_BOX", "Informe DEPOSIT ou WITHDRAW")
        elif kind == "OVERDRAFT":
            transaction_id = self.ledger.external_credit(
                account_number,
                value,
                idempotency_key,
                kind,
                "Uso de cheque especial",
                source_account="CREDIT_PORTFOLIO",
                created_by=actor_id,
                metadata=metadata,
            )
        elif kind in {"FX_BUY", "FX_SELL", "PORTABILITY", "BUSINESS_ACCOUNT", "DEBT_RENEGOTIATION"}:
            direction = (payload or {}).get("direction", "DEBIT")
            method = self.ledger.external_debit if direction == "DEBIT" else self.ledger.external_credit
            transaction_id = method(
                account_number,
                value,
                idempotency_key,
                kind,
                f"{module}: {kind}",
                created_by=actor_id,
                metadata=metadata,
            )
        else:
            raise BankError("UNSUPPORTED_SETTLEMENT", f"Liquidação não definida: {kind}")
        now = utcnow()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO module_events VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    str(uuid.uuid4()),
                    module,
                    kind,
                    account_number,
                    value,
                    transaction_id,
                    json.dumps(payload or {}, sort_keys=True),
                    "SETTLED",
                    now,
                ),
            )
            con.execute(
                "INSERT INTO outbox VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    str(uuid.uuid4()),
                    "IN_APP",
                    account_number,
                    "FINANCIAL_EVENT",
                    json.dumps(
                        {
                            "module": module,
                            "kind": kind,
                            "amount_cents": value,
                            "transaction_id": transaction_id,
                        },
                        sort_keys=True,
                    ),
                    "PENDING",
                    0,
                    now,
                    None,
                ),
            )
        return transaction_id

    def schedule(
        self,
        kind: str,
        payload: dict[str, Any],
        next_run_at: str,
        *,
        recurrence: str = "ONCE",
        end_at: str | None = None,
    ) -> str:
        if recurrence not in {"ONCE", "DAILY", "WEEKLY", "MONTHLY"}:
            raise BankError("INVALID_RECURRENCE", "Recorrência inválida")
        job_id = str(uuid.uuid4())
        now = utcnow()
        with self.db.transaction() as con:
            con.execute(
                """INSERT INTO scheduled_jobs(
                     job_id,kind,payload,recurrence,next_run_at,end_at,state,
                     attempts,last_error,idempotency_prefix,created_at,updated_at,
                     anchor_day
                   ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    job_id,
                    kind,
                    json.dumps(payload, sort_keys=True),
                    recurrence,
                    next_run_at,
                    end_at,
                    "ACTIVE",
                    0,
                    None,
                    f"job:{job_id}",
                    now,
                    now,
                    datetime.fromisoformat(next_run_at).day if recurrence == "MONTHLY" else None,
                ),
            )
        return job_id

    def settle_card_purchase(
        self,
        account_number: str,
        amount: Decimal | str | int,
        cashback_percent: Decimal | str | int,
        idempotency_key: str,
        *,
        actor_id: str | None = None,
        merchant: str = "",
    ) -> dict[str, Any]:
        """Liquida compra e fidelidade em uma única transação contábil."""
        if actor_id and self.security:
            self.security.require_account_access(actor_id, account_number, "TRANSACT")
        purchase = money_to_cents(amount)
        percent = Decimal(str(cashback_percent).replace(",", "."))
        if purchase <= 0 or percent < 0 or percent > 100:
            raise BankError("INVALID_CARD_PURCHASE", "Compra ou percentual inválido")
        cashback = int(
            (Decimal(purchase) * percent / Decimal(100)).quantize(Decimal("1"), rounding=ROUND_HALF_EVEN)
        )
        postings = [
            Posting(
                "CUSTOMER_DEPOSITS",
                debit_cents=purchase,
                customer_account=account_number,
                memo=merchant,
            ),
            Posting("SETTLEMENT", credit_cents=purchase, memo=merchant),
        ]
        if cashback:
            postings.extend(
                [
                    Posting("OPERATING_EXPENSE", debit_cents=cashback, memo="Cashback"),
                    Posting(
                        "CUSTOMER_DEPOSITS",
                        credit_cents=cashback,
                        customer_account=account_number,
                        memo="Cashback",
                    ),
                ]
            )
        transaction_id = self.ledger.post(
            "CARD_PURCHASE",
            idempotency_key,
            f"Compra cartão: {merchant}",
            postings,
            created_by=actor_id,
            balance_deltas={account_number: -purchase + cashback},
            metadata={"merchant": merchant, "cashback_cents": cashback},
        )
        return {"transaction_id": transaction_id, "cashback_cents": cashback}

    def calculate_credit_score(self, account_number: str) -> dict[str, Any]:
        """Score explicável calculado exclusivamente a partir de dados reais."""
        account = self.ledger.account(account_number)
        with self.db.connect() as con:
            stats = con.execute(
                """SELECT COUNT(*) AS operations,
                          COALESCE(SUM(CASE WHEN e.debit_cents>0
                                           THEN e.debit_cents ELSE 0 END),0) AS debits,
                          COALESCE(SUM(CASE WHEN t.kind='REVERSAL'
                                           THEN 1 ELSE 0 END),0) AS reversals
                   FROM ledger_entries e
                   JOIN ledger_transactions t USING(transaction_id)
                   WHERE e.customer_account=? AND t.state='SETTLED'""",
                (account_number,),
            ).fetchone()
        balance_cents = account["ledger_balance_cents"]
        overdraft = account["overdraft_limit_cents"]
        utilization = max(0, -balance_cents) / overdraft if overdraft else 0
        relationship = min(150, int(stats["operations"]) * 3)
        balance_factor = 200 if balance_cents >= 0 else max(0, 200 - int(utilization * 200))
        reversal_penalty = min(150, int(stats["reversals"]) * 15)
        score = max(0, min(1000, 500 + relationship + balance_factor - reversal_penalty))
        rating = (
            "A"
            if score >= 800
            else "B"
            if score >= 650
            else "C"
            if score >= 500
            else "D"
            if score >= 350
            else "E"
        )
        return {
            "account_number": account_number,
            "score": score,
            "rating": rating,
            "factors": {
                "relationship_points": relationship,
                "balance_points": balance_factor,
                "reversal_penalty": reversal_penalty,
                "operations": int(stats["operations"]),
            },
        }

    def run_due(self, at: str | None = None) -> dict[str, int]:
        at = at or utcnow()
        processed = failed = 0
        with self.db.connect() as con:
            jobs = con.execute(
                """SELECT * FROM scheduled_jobs
                   WHERE state='ACTIVE' AND next_run_at<=?
                   ORDER BY next_run_at""",
                (at,),
            ).fetchall()
        for job in jobs:
            payload = json.loads(job["payload"])
            try:
                self.settle(
                    payload["module"],
                    job["kind"],
                    payload["account_number"],
                    payload["amount"],
                    f"{job['idempotency_prefix']}:{job['next_run_at']}",
                    actor_id=payload.get("actor_id"),
                    payload=payload.get("details"),
                )
                processed += 1
                next_run = self._next_run(job["next_run_at"], job["recurrence"], job["anchor_day"])
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
            except Exception as exc:
                failed += 1
                attempts = job["attempts"] + 1
                state = "FAILED" if attempts >= self.MAX_JOB_ATTEMPTS else "ACTIVE"
                retry_at = self.retry_at(attempts)
                LOGGER.warning(
                    "scheduler.job_failed",
                    extra={
                        "job_id": job["job_id"],
                        "kind": job["kind"],
                        "attempt": attempts,
                        "state": state,
                        "retry_at": retry_at,
                        "error": type(exc).__name__,
                    },
                )
                with self.db.transaction() as con:
                    con.execute(
                        """UPDATE scheduled_jobs SET attempts=?,state=?,last_error=?,
                           next_run_at=?,updated_at=? WHERE job_id=?""",
                        (attempts, state, str(exc)[:500], retry_at, utcnow(), job["job_id"]),
                    )
        METRICS.increment("scheduler_jobs_processed_total", value=processed)
        METRICS.increment("scheduler_jobs_failed_total", value=failed)
        return {"processed": processed, "failed": failed}

    MAX_JOB_ATTEMPTS = 5
    RETRY_BASE_SECONDS = 60

    @classmethod
    def retry_at(cls, attempts: int) -> str:
        """Backoff exponencial limitado a 1 h, medido a partir de agora."""
        delay = min(3600, cls.RETRY_BASE_SECONDS * 2 ** (attempts - 1))
        return (datetime.now(UTC) + timedelta(seconds=delay)).isoformat()

    @staticmethod
    def _next_run(current: str, recurrence: str, anchor_day: int | None = None) -> str:
        """Próxima execução.

        ``anchor_day`` preserva o dia contratado da recorrência mensal. Sem ele,
        uma cobrança do dia 31 cai em 28 ao passar por fevereiro e **fica** no
        28 para sempre, porque o cálculo seguinte parte da data já degradada.
        O vencimento contratual do cliente não pode andar sozinho.
        """
        moment = datetime.fromisoformat(current)
        if recurrence == "DAILY":
            moment += timedelta(days=1)
        elif recurrence == "WEEKLY":
            moment += timedelta(days=7)
        elif recurrence == "MONTHLY":
            month = moment.month + 1
            year = moment.year + (month - 1) // 12
            month = (month - 1) % 12 + 1
            day = anchor_day or moment.day
            while day > 1:
                try:
                    return moment.replace(year=year, month=month, day=day).isoformat()
                except ValueError:
                    day -= 1
            moment = moment.replace(year=year, month=month, day=1)
        return moment.isoformat()


class OutboxService:
    """Entrega local determinística para e-mail, SMS e notificações in-app."""

    def __init__(self, database: BankDatabase, directory: str | Path = "BANKMAILBOX"):
        self.db = database
        self.directory = Path(directory)

    def deliver_pending(self, limit: int = 100) -> dict[str, int]:
        self.directory.mkdir(parents=True, exist_ok=True)
        delivered = failed = 0
        with self.db.connect() as con:
            messages = con.execute(
                "SELECT * FROM outbox WHERE state='PENDING' ORDER BY created_at LIMIT ?",
                (limit,),
            ).fetchall()
        for message in messages:
            try:
                recipient = re.sub(r"[^A-Za-z0-9_.@+-]", "_", message["recipient"])
                target = self.directory / (
                    f"{message['created_at'].replace(':', '-')}_"
                    f"{message['channel']}_{recipient}_{message['message_id']}.json"
                )
                target.write_text(
                    json.dumps(dict(message), ensure_ascii=False, indent=2),
                    encoding="utf-8",
                )
                with self.db.transaction() as con:
                    con.execute(
                        """UPDATE outbox SET state='SENT',attempts=attempts+1,sent_at=?
                           WHERE message_id=?""",
                        (utcnow(), message["message_id"]),
                    )
                delivered += 1
            except OSError:
                with self.db.transaction() as con:
                    con.execute(
                        """UPDATE outbox SET attempts=attempts+1,
                           state=CASE WHEN attempts+1>=5 THEN 'FAILED' ELSE 'PENDING' END
                           WHERE message_id=?""",
                        (message["message_id"],),
                    )
                failed += 1
        return {"delivered": delivered, "failed": failed}


class BankingCore:
    """Fachada única usada pela CLI, GUI, testes e adaptadores COBOL."""

    def __init__(self, database_path: str | Path = "BANKCORE.db", with_security: bool = True):
        self.database = BankDatabase(database_path)
        self.ledger = LedgerService(self.database)
        self.security = SecurityService(self.database) if with_security else None
        self.modules = ModuleIntegrationService(self.database, self.ledger, self.security)
        self.outbox = OutboxService(self.database, Path(database_path).parent / "BANKMAILBOX")

    def execute_admin_adjustment(
        self,
        approval_id: str,
        executor_id: str,
        account_number: str,
        amount: Decimal | str | int,
        direction: str,
        reason: str,
    ) -> str:
        if self.security is None:
            raise AuthorizationError("SECURITY_DISABLED", "Segurança desativada")
        self.security.require_permission(executor_id, "ADMIN_ADJUST")
        with self.database.transaction() as con:
            approval = con.execute("SELECT * FROM approvals WHERE approval_id=?", (approval_id,)).fetchone()
            if (
                approval is None
                or approval["state"] != "APPROVED"
                or approval["action"] != "ADMIN_ADJUSTMENT"
                or approval["resource_id"] != account_number
            ):
                raise AuthorizationError("APPROVAL_REQUIRED", "Ajuste exige aprovação válida")
            con.execute(
                "UPDATE approvals SET state='EXECUTING' WHERE approval_id=?",
                (approval_id,),
            )
        try:
            if direction == "CREDIT":
                transaction_id = self.ledger.external_credit(
                    account_number,
                    amount,
                    f"adjustment:{approval_id}",
                    "ADMIN_ADJUSTMENT",
                    reason,
                    created_by=executor_id,
                    source_account="OPERATING_EXPENSE",
                    metadata={"approval_id": approval_id},
                )
            elif direction == "DEBIT":
                transaction_id = self.ledger.external_debit(
                    account_number,
                    amount,
                    f"adjustment:{approval_id}",
                    "ADMIN_ADJUSTMENT",
                    reason,
                    created_by=executor_id,
                    destination_account="FEE_REVENUE",
                    metadata={"approval_id": approval_id},
                )
            else:
                raise AccountingError("INVALID_DIRECTION", "Use CREDIT ou DEBIT")
        except Exception:
            with self.database.transaction() as con:
                con.execute(
                    "UPDATE approvals SET state='APPROVED' WHERE approval_id=?",
                    (approval_id,),
                )
            raise
        with self.database.transaction() as con:
            con.execute(
                "UPDATE approvals SET state='EXECUTED',decided_at=? WHERE approval_id=?",
                (utcnow(), approval_id),
            )
        self.security.audit(
            executor_id,
            "ADMIN_ADJUSTMENT_EXECUTE",
            account_number,
            "SUCCESS",
            {"approval_id": approval_id, "transaction_id": transaction_id},
        )
        return transaction_id
