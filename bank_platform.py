"""Finanças pessoais, notificações, LGPD, compliance e administração."""

from __future__ import annotations

import hashlib
import json
import re
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

from bank_core import (
    AuthorizationError,
    BankDatabase,
    BankError,
    LedgerService,
    SecurityService,
    money_to_cents,
    utcnow,
)


class PlatformSchema:
    def __init__(self, db: BankDatabase):
        self.db = db
        with db.transaction() as con:
            con.executescript("""
            CREATE TABLE IF NOT EXISTS pfm_rules(rule_id TEXT PRIMARY KEY,user_id TEXT,
              pattern TEXT NOT NULL,category TEXT NOT NULL,priority INTEGER NOT NULL,active INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS pfm_categories(transaction_id TEXT NOT NULL,user_id TEXT NOT NULL,
              category TEXT NOT NULL,amount_cents INTEGER NOT NULL,source TEXT NOT NULL,
              PRIMARY KEY(transaction_id,user_id,category));
            CREATE TABLE IF NOT EXISTS pfm_budgets(user_id TEXT NOT NULL,month TEXT NOT NULL,
              category TEXT NOT NULL,limit_cents INTEGER NOT NULL,alert_percent INTEGER NOT NULL,
              PRIMARY KEY(user_id,month,category));
            CREATE TABLE IF NOT EXISTS pfm_goals(goal_id TEXT PRIMARY KEY,user_id TEXT NOT NULL,
              name TEXT NOT NULL,target_cents INTEGER NOT NULL,current_cents INTEGER NOT NULL,
              due_at TEXT,account_number TEXT,state TEXT NOT NULL,created_at TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS pfm_recurring(item_id TEXT PRIMARY KEY,user_id TEXT NOT NULL,
              kind TEXT NOT NULL,name TEXT NOT NULL,amount_cents INTEGER NOT NULL,
              recurrence TEXT NOT NULL,next_date TEXT NOT NULL,category TEXT,state TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS notifications(notification_id TEXT PRIMARY KEY,user_id TEXT NOT NULL,
              event TEXT NOT NULL,title TEXT NOT NULL,body TEXT NOT NULL,severity TEXT NOT NULL,
              state TEXT NOT NULL,action_state TEXT,created_at TEXT NOT NULL,read_at TEXT);
            CREATE TABLE IF NOT EXISTS notification_preferences(user_id TEXT NOT NULL,event TEXT NOT NULL,
              channels TEXT NOT NULL,quiet_start INTEGER,quiet_end INTEGER,enabled INTEGER NOT NULL,
              PRIMARY KEY(user_id,event));
            CREATE TABLE IF NOT EXISTS notification_templates(template_id TEXT PRIMARY KEY,event TEXT NOT NULL,
              version INTEGER NOT NULL,title TEXT NOT NULL,body TEXT NOT NULL,active INTEGER NOT NULL,
              UNIQUE(event,version));
            CREATE TABLE IF NOT EXISTS support_tickets(protocol TEXT PRIMARY KEY,user_id TEXT NOT NULL,
              subject TEXT NOT NULL,status TEXT NOT NULL,priority TEXT NOT NULL,due_at TEXT NOT NULL,
              rating INTEGER,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS support_messages(message_id TEXT PRIMARY KEY,protocol TEXT NOT NULL,
              author TEXT NOT NULL,body TEXT NOT NULL,attachment TEXT,created_at TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS knowledge_base(article_id TEXT PRIMARY KEY,title TEXT NOT NULL,
              content TEXT NOT NULL,tags TEXT NOT NULL,version INTEGER NOT NULL,active INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS privacy_inventory(data_id TEXT PRIMARY KEY,name TEXT NOT NULL,
              purpose TEXT NOT NULL,legal_basis TEXT NOT NULL,retention_days INTEGER NOT NULL,
              sensitive INTEGER NOT NULL,system TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS privacy_requests(request_id TEXT PRIMARY KEY,user_id TEXT NOT NULL,
              kind TEXT NOT NULL,state TEXT NOT NULL,payload TEXT NOT NULL,evidence TEXT,
              due_at TEXT NOT NULL,created_at TEXT NOT NULL,completed_at TEXT);
            CREATE TABLE IF NOT EXISTS legal_holds(hold_id TEXT PRIMARY KEY,user_id TEXT,reason TEXT NOT NULL,
              scope TEXT NOT NULL,state TEXT NOT NULL,created_at TEXT NOT NULL,released_at TEXT);
            CREATE TABLE IF NOT EXISTS privacy_incidents(incident_id TEXT PRIMARY KEY,severity TEXT NOT NULL,
              description TEXT NOT NULL,state TEXT NOT NULL,impact TEXT NOT NULL,
              actions TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS sensitive_access(access_id TEXT PRIMARY KEY,actor TEXT NOT NULL,
              user_id TEXT NOT NULL,resource TEXT NOT NULL,purpose TEXT NOT NULL,created_at TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS compliance_policies(policy_id TEXT PRIMARY KEY,name TEXT NOT NULL,
              version INTEGER NOT NULL,parameters TEXT NOT NULL,state TEXT NOT NULL,created_at TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS compliance_cases(case_id TEXT PRIMARY KEY,scenario TEXT NOT NULL,
              subject TEXT NOT NULL,risk INTEGER NOT NULL,state TEXT NOT NULL,evidence TEXT NOT NULL,
              assigned_to TEXT,approval TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS regulatory_reports(report_id TEXT PRIMARY KEY,kind TEXT NOT NULL,
              version TEXT NOT NULL,period TEXT NOT NULL,payload TEXT NOT NULL,digest TEXT NOT NULL,
              protocol TEXT NOT NULL,state TEXT NOT NULL,created_at TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS system_settings(key TEXT PRIMARY KEY,value TEXT NOT NULL,
              environment TEXT NOT NULL,updated_by TEXT NOT NULL,updated_at TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS report_history(report_id TEXT PRIMARY KEY,kind TEXT NOT NULL,
              filters TEXT NOT NULL,payload TEXT NOT NULL,digest TEXT NOT NULL,created_by TEXT NOT NULL,
              created_at TEXT NOT NULL);
            """)


class PersonalFinanceService:
    def __init__(self, db: BankDatabase, ledger: LedgerService, security: SecurityService | None = None):
        self.db, self.ledger, self.security = db, ledger, security
        PlatformSchema(db)

    def _require_debit_authority(self, actor_id: str | None, account: str) -> None:
        """Com RBAC ativo, nenhum débito corre sem prova de titularidade."""
        if not self.security:
            return
        if not actor_id:
            raise AuthorizationError("ACTOR_REQUIRED", "Débito exige usuário autenticado")
        self.security.require_account_access(actor_id, account, "TRANSACT")

    MAX_PATTERN_LENGTH = 200
    MAX_PATTERN_SUBJECT = 500

    def add_rule(self, user: str, pattern: str, category: str, priority: int = 100) -> str:
        if len(pattern) > self.MAX_PATTERN_LENGTH:
            raise BankError("PATTERN_TOO_LONG", "Padrão de categorização longo demais")
        re.compile(pattern)
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO pfm_rules VALUES(?,?,?,?,?,1)", (identifier, user, pattern, category, priority)
            )
        return identifier

    def categorize(self, user: str, transaction_id: str, description: str, amount: str) -> str:
        with self.db.connect() as con:
            rules = con.execute(
                "SELECT * FROM pfm_rules WHERE (user_id=? OR user_id IS NULL) AND active=1 ORDER BY priority",
                (user,),
            ).fetchall()
        category = "OUTROS"
        subject = description[: self.MAX_PATTERN_SUBJECT]
        for rule in rules:
            try:
                matched = re.search(rule["pattern"], subject, re.I)
            except re.error:
                continue
            if matched:
                category = rule["category"]
                break
        with self.db.transaction() as con:
            con.execute(
                "INSERT OR REPLACE INTO pfm_categories VALUES(?,?,?,?,?)",
                (transaction_id, user, category, money_to_cents(amount), "RULE" if rules else "DEFAULT"),
            )
        return category

    def split(self, user: str, transaction_id: str, parts: dict[str, str]) -> None:
        cents = {category: money_to_cents(value) for category, value in parts.items()}
        if any(value <= 0 for value in cents.values()):
            raise BankError("INVALID_SPLIT", "Divisão inválida")
        with self.db.transaction() as con:
            con.execute(
                "DELETE FROM pfm_categories WHERE transaction_id=? AND user_id=?", (transaction_id, user)
            )
            for category, value in cents.items():
                con.execute(
                    "INSERT INTO pfm_categories VALUES(?,?,?,?,?)",
                    (transaction_id, user, category, value, "USER_SPLIT"),
                )

    def budget(self, user: str, month: str, category: str, limit: str, alert: int = 80) -> None:
        if not re.fullmatch(r"\d{4}-\d{2}", month) or not 1 <= alert <= 100:
            raise BankError("INVALID_BUDGET", "Orçamento inválido")
        with self.db.transaction() as con:
            con.execute(
                "INSERT OR REPLACE INTO pfm_budgets VALUES(?,?,?,?,?)",
                (user, month, category, money_to_cents(limit), alert),
            )

    def budget_status(self, user: str, month: str) -> list[dict[str, Any]]:
        with self.db.connect() as con:
            rows = con.execute(
                """SELECT b.*,COALESCE(SUM(c.amount_cents),0) spent
              FROM pfm_budgets b LEFT JOIN pfm_categories c ON c.user_id=b.user_id
              AND c.category=b.category WHERE b.user_id=? AND b.month=? GROUP BY b.category""",
                (user, month),
            ).fetchall()
        return [
            {
                **dict(r),
                "percent": round(r["spent"] * 100 / r["limit_cents"], 2) if r["limit_cents"] else 0,
                "alert": r["spent"] * 100 >= r["limit_cents"] * r["alert_percent"],
            }
            for r in rows
        ]

    def goal(
        self, user: str, name: str, target: str, due_at: str | None = None, account: str | None = None
    ) -> str:
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO pfm_goals VALUES(?,?,?,?,?,?,?,?,?)",
                (identifier, user, name, money_to_cents(target), 0, due_at, account, "ACTIVE", utcnow()),
            )
        return identifier

    def contribute(
        self,
        goal_id: str,
        amount: str,
        source_account: str | None = None,
        idempotency: str | None = None,
        actor_id: str | None = None,
    ) -> None:
        """Aporta em uma meta, opcionalmente debitando uma conta.

        `idempotency` é obrigatória quando há débito: a chave anterior continha
        `uuid4()`, então cada retentativa debitava o cliente de novo.
        """
        value = money_to_cents(amount)
        with self.db.transaction() as con:
            goal = con.execute(
                "SELECT * FROM pfm_goals WHERE goal_id=? AND state='ACTIVE'", (goal_id,)
            ).fetchone()
            if not goal:
                raise BankError("GOAL_NOT_FOUND", "Meta não encontrada")
        if source_account:
            self._require_debit_authority(actor_id, source_account)
            self.ledger.external_debit(
                source_account,
                value,
                f"goal:{goal_id}:{idempotency or uuid.uuid4()}",
                "SAVINGS_GOAL",
                "Aporte em meta",
                destination_account="BLOCKED_FUNDS",
                created_by=actor_id,
            )
        with self.db.transaction() as con:
            con.execute(
                """UPDATE pfm_goals SET current_cents=current_cents+?,
          state=CASE WHEN current_cents+?>=target_cents THEN 'COMPLETED' ELSE state END WHERE goal_id=?""",
                (value, value, goal_id),
            )

    def dashboard(self, user: str) -> dict[str, Any]:
        with self.db.connect() as con:
            accounts = con.execute("SELECT * FROM customer_accounts WHERE owner_id=?", (user,)).fetchall()
            goals = con.execute("SELECT * FROM pfm_goals WHERE user_id=?", (user,)).fetchall()
            recurring = con.execute(
                "SELECT * FROM pfm_recurring WHERE user_id=? AND state='ACTIVE'", (user,)
            ).fetchall()
        assets = sum(max(0, r["ledger_balance_cents"]) for r in accounts)
        debts = sum(max(0, -r["ledger_balance_cents"]) for r in accounts)
        projected = sum(r["projected_balance_cents"] for r in accounts)
        health = max(0, min(100, 50 + (20 if assets > debts else -20) + (15 if projected >= 0 else -15)))
        return {
            "assets_cents": assets,
            "debts_cents": debts,
            "net_worth_cents": assets - debts,
            "projected_cents": projected,
            "health_score": health,
            "goals": [dict(r) for r in goals],
            "calendar": [dict(r) for r in recurring],
            "insights": [
                {"reason": "SALDO_PROJETADO", "message": "Mantenha reserva de emergência", "advice": False}
            ],
        }


class NotificationService:
    def __init__(self, db: BankDatabase):
        self.db = db
        PlatformSchema(db)

    def template(self, event: str, version: int, title: str, body: str) -> str:
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute("UPDATE notification_templates SET active=0 WHERE event=?", (event,))
            con.execute(
                "INSERT INTO notification_templates VALUES(?,?,?,?,?,1)",
                (identifier, event, version, title, body),
            )
        return identifier

    def preferences(
        self, user: str, event: str, channels: list[str], quiet: tuple[int, int] | None = None
    ) -> None:
        allowed = {"IN_APP", "EMAIL", "SMS", "PUSH"}
        if not set(channels) <= allowed:
            raise BankError("INVALID_CHANNEL", "Canal inválido")
        with self.db.transaction() as con:
            con.execute(
                "INSERT OR REPLACE INTO notification_preferences VALUES(?,?,?,?,?,1)",
                (user, event, json.dumps(channels), quiet[0] if quiet else None, quiet[1] if quiet else None),
            )

    def notify(self, user: str, event: str, data: dict[str, Any], severity: str = "INFO") -> str:
        with self.db.connect() as con:
            tpl = con.execute(
                "SELECT * FROM notification_templates WHERE event=? AND active=1 ORDER BY version DESC LIMIT 1",
                (event,),
            ).fetchone()
        title = (tpl["title"] if tpl else event).format_map(data)
        body = (tpl["body"] if tpl else json.dumps(data)).format_map(data)
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO notifications VALUES(?,?,?,?,?,?,?,?,?,?)",
                (identifier, user, event, title, body, severity, "UNREAD", None, utcnow(), None),
            )
        return identifier

    def read(self, user: str, notification: str) -> None:
        with self.db.transaction() as con:
            con.execute(
                "UPDATE notifications SET state='READ',read_at=? WHERE notification_id=? AND user_id=?",
                (utcnow(), notification, user),
            )

    def ticket(self, user: str, subject: str, priority: str = "NORMAL", sla_hours: int = 48) -> str:
        protocol = "SUP" + datetime.now(UTC).strftime("%Y%m%d%H%M%S") + secrets.token_hex(2).upper()
        now = utcnow()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO support_tickets VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    protocol,
                    user,
                    subject,
                    "OPEN",
                    priority,
                    (datetime.now(UTC) + timedelta(hours=sla_hours)).isoformat(),
                    None,
                    now,
                    now,
                ),
            )
        return protocol

    def message(self, protocol: str, author: str, body: str, attachment: str | None = None) -> str:
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO support_messages VALUES(?,?,?,?,?,?)",
                (identifier, protocol, author, body, attachment, utcnow()),
            )
        return identifier

    def search_kb(self, query: str) -> list[dict[str, Any]]:
        with self.db.connect() as con:
            return [
                dict(r)
                for r in con.execute(
                    "SELECT * FROM knowledge_base WHERE active=1 AND (title LIKE ? OR content LIKE ?)",
                    (f"%{query}%", f"%{query}%"),
                )
            ]


class PrivacyService:
    def __init__(self, db: BankDatabase):
        self.db = db
        PlatformSchema(db)

    def inventory(
        self, name: str, purpose: str, basis: str, retention: int, sensitive: bool, system: str
    ) -> str:
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO privacy_inventory VALUES(?,?,?,?,?,?,?)",
                (identifier, name, purpose, basis, retention, int(sensitive), system),
            )
        return identifier

    def request(self, user: str, kind: str, payload: dict[str, Any] | None = None) -> str:
        allowed = {
            "ACCESS",
            "EXPORT",
            "CORRECT",
            "ANONYMIZE",
            "BLOCK",
            "DELETE",
            "PORTABILITY",
            "REVIEW_DECISION",
        }
        if kind not in allowed:
            raise BankError("INVALID_PRIVACY_REQUEST", "Direito inválido")
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO privacy_requests VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    identifier,
                    user,
                    kind,
                    "OPEN",
                    json.dumps(payload or {}),
                    None,
                    (datetime.now(UTC) + timedelta(days=15)).isoformat(),
                    utcnow(),
                    None,
                ),
            )
        return identifier

    def export_subject(self, user: str) -> dict[str, Any]:
        with self.db.connect() as con:
            accounts = [
                dict(r) for r in con.execute("SELECT * FROM customer_accounts WHERE owner_id=?", (user,))
            ]
            has_consents = con.execute(
                "SELECT 1 FROM sqlite_master WHERE type='table' AND name='consents'"
            ).fetchone()
            consents = (
                [dict(r) for r in con.execute("SELECT * FROM consents WHERE customer_id=?", (user,))]
                if has_consents
                else []
            )
            access = [dict(r) for r in con.execute("SELECT * FROM sensitive_access WHERE user_id=?", (user,))]
        return {"user_id": user, "accounts": accounts, "consents": consents, "access_log": access}

    def legal_hold(self, user: str | None, reason: str, scope: str) -> str:
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO legal_holds VALUES(?,?,?,?,?,?,?)",
                (identifier, user, reason, scope, "ACTIVE", utcnow(), None),
            )
        return identifier

    def access_log(self, actor: str, user: str, resource: str, purpose: str) -> None:
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO sensitive_access VALUES(?,?,?,?,?,?)",
                (str(uuid.uuid4()), actor, user, resource, purpose, utcnow()),
            )

    def incident(self, severity: str, description: str, impact: dict[str, Any]) -> str:
        identifier, now = str(uuid.uuid4()), utcnow()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO privacy_incidents VALUES(?,?,?,?,?,?,?,?)",
                (identifier, severity, description, "OPEN", json.dumps(impact), "[]", now, now),
            )
        return identifier


class ComplianceService:
    def __init__(self, db: BankDatabase):
        self.db = db
        PlatformSchema(db)

    def policy(self, name: str, version: int, parameters: dict[str, Any]) -> str:
        identifier = str(uuid.uuid4())
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO compliance_policies VALUES(?,?,?,?,?,?)",
                (identifier, name, version, json.dumps(parameters), "ACTIVE", utcnow()),
            )
        return identifier

    def monitor(self, subject: str, transactions: list[dict[str, Any]], threshold_cents: int) -> list[str]:
        cases = []
        total = sum(int(item["amount_cents"]) for item in transactions)
        scenarios = []
        if total >= threshold_cents:
            scenarios.append(("HIGH_VOLUME", 70))
        amounts = [int(item["amount_cents"]) for item in transactions]
        if (
            len(amounts) >= 3
            and all(value < threshold_cents for value in amounts)
            and total >= threshold_cents
        ):
            scenarios.append(("STRUCTURING", 90))
        for scenario, risk in scenarios:
            identifier = str(uuid.uuid4())
            now = utcnow()
            with self.db.transaction() as con:
                con.execute(
                    "INSERT INTO compliance_cases VALUES(?,?,?,?,?,?,?,?,?,?)",
                    (
                        identifier,
                        scenario,
                        subject,
                        risk,
                        "OPEN",
                        json.dumps(transactions),
                        None,
                        None,
                        now,
                        now,
                    ),
                )
            cases.append(identifier)
        return cases

    def regulatory_report(
        self, kind: str, version: str, period: str, payload: dict[str, Any]
    ) -> dict[str, str]:
        raw = json.dumps(payload, sort_keys=True)
        digest = hashlib.sha256(raw.encode()).hexdigest()
        report = str(uuid.uuid4())
        protocol = "REG" + secrets.token_hex(6).upper()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO regulatory_reports VALUES(?,?,?,?,?,?,?,?,?)",
                (report, kind, version, period, raw, digest, protocol, "GENERATED", utcnow()),
            )
        return {"report_id": report, "protocol": protocol, "digest": digest}


class ReportingService:
    def __init__(self, db: BankDatabase):
        self.db = db
        PlatformSchema(db)

    def dashboard(self, start: str = "0000-01-01", end: str = "9999-12-31") -> dict[str, Any]:
        with self.db.connect() as con:
            tx = con.execute(
                """SELECT COUNT(*) count,COALESCE(SUM(e.debit_cents),0) volume
              FROM ledger_transactions t JOIN ledger_entries e USING(transaction_id)
              WHERE t.accounting_date BETWEEN ? AND ? AND t.state='SETTLED'""",
                (start, end),
            ).fetchone()
            accounts = con.execute("""SELECT kind,COUNT(*) count,SUM(ledger_balance_cents) balance,
              SUM(blocked_balance_cents) blocked FROM customer_accounts GROUP BY kind""").fetchall()
            revenue = con.execute("""SELECT account_code,SUM(credit_cents-debit_cents) total
              FROM ledger_entries WHERE account_code IN ('FEE_REVENUE','INTEREST_REVENUE')
              GROUP BY account_code""").fetchall()
        return {
            "transactions": dict(tx),
            "accounts": [dict(r) for r in accounts],
            "revenue": [dict(r) for r in revenue],
            "generated_at": utcnow(),
        }

    def setting(self, key: str, value: Any, environment: str, actor: str) -> None:
        with self.db.transaction() as con:
            con.execute(
                "INSERT OR REPLACE INTO system_settings VALUES(?,?,?,?,?)",
                (key, json.dumps(value), environment, actor, utcnow()),
            )

    def report(self, kind: str, filters: dict[str, Any], actor: str) -> dict[str, str]:
        payload = self.dashboard(filters.get("start", "0000-01-01"), filters.get("end", "9999-12-31"))
        raw = json.dumps(payload, sort_keys=True)
        identifier = str(uuid.uuid4())
        digest = hashlib.sha256(raw.encode()).hexdigest()
        with self.db.transaction() as con:
            con.execute(
                "INSERT INTO report_history VALUES(?,?,?,?,?,?,?)",
                (identifier, kind, json.dumps(filters), raw, digest, actor, utcnow()),
            )
        return {"report_id": identifier, "digest": digest, "payload": raw}


class BankPlatform:
    def __init__(self, db: BankDatabase, ledger: LedgerService, security: SecurityService | None = None):
        self.personal = PersonalFinanceService(db, ledger, security)
        self.notifications = NotificationService(db)
        self.privacy = PrivacyService(db)
        self.compliance = ComplianceService(db)
        self.reports = ReportingService(db)
