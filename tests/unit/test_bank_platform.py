from decimal import Decimal

from bank_core import BankDatabase, LedgerService
from bank_platform import BankPlatform


def setup_platform(tmp_path):
    db = BankDatabase(tmp_path / "platform.db")
    ledger = LedgerService(db)
    ledger.create_account("1001", "user", initial_balance="1000")
    return BankPlatform(db, ledger), db, ledger


def test_personal_finance_rules_budgets_goals_and_dashboard(tmp_path):
    app, _, ledger = setup_platform(tmp_path)
    app.personal.add_rule("user", "mercado", "ALIMENTACAO")
    assert app.personal.categorize("user", "tx1", "Mercado Central", "100") == "ALIMENTACAO"
    app.personal.split("user", "tx1", {"ALIMENTACAO": "60", "CASA": "40"})
    app.personal.budget("user", "2026-07", "ALIMENTACAO", "50", 80)
    assert app.personal.budget_status("user", "2026-07")[0]["alert"]
    goal = app.personal.goal("user", "Reserva", "200", account="1001")
    app.personal.contribute(goal, "50", "1001")
    assert ledger.account("1001")["ledger_balance"] == Decimal("950.00")
    assert app.personal.dashboard("user")["health_score"] >= 0


def test_notifications_preferences_templates_read_and_support(tmp_path):
    app, db, _ = setup_platform(tmp_path)
    app.notifications.template("PIX_RECEIVED", 1, "PIX recebido", "Valor: {amount}")
    app.notifications.preferences("user", "PIX_RECEIVED", ["IN_APP", "EMAIL"], (22, 6))
    notification = app.notifications.notify("user", "PIX_RECEIVED", {"amount": "10"})
    app.notifications.read("user", notification)
    protocol = app.notifications.ticket("user", "Ajuda")
    app.notifications.message(protocol, "user", "Mensagem", "attachment-id")
    with db.connect() as con:
        assert (
            con.execute(
                "SELECT state FROM notifications WHERE notification_id=?", (notification,)
            ).fetchone()[0]
            == "READ"
        )


def test_privacy_inventory_requests_export_holds_incidents_and_access(tmp_path):
    app, _, _ = setup_platform(tmp_path)
    app.privacy.inventory("CPF", "Identificação", "Contrato", 1825, True, "KYC")
    assert app.privacy.request("user", "EXPORT")
    app.privacy.access_log("employee", "user", "CUSTOMER_PII", "Atendimento")
    exported = app.privacy.export_subject("user")
    assert exported["accounts"][0]["account_number"] == "1001"
    assert app.privacy.legal_hold("user", "Investigação", "ALL")
    assert app.privacy.incident("HIGH", "Exposição", {"records": 1})


def test_compliance_structuring_reports_and_dashboard(tmp_path):
    app, db, ledger = setup_platform(tmp_path)
    app.compliance.policy("PLD", 1, {"threshold": 10000})
    cases = app.compliance.monitor(
        "user", [{"amount_cents": 4000}, {"amount_cents": 4000}, {"amount_cents": 4000}], 10000
    )
    assert len(cases) == 2
    regulatory = app.compliance.regulatory_report("SCR", "1.0", "2026-07", {"risk": 100})
    assert regulatory["protocol"].startswith("REG")
    ledger.external_debit("1001", "10", "fee-platform", "FEE", "Tarifa", destination_account="FEE_REVENUE")
    dashboard = app.reports.dashboard()
    assert dashboard["transactions"]["count"] > 0
    app.reports.setting("feature.pix", True, "TEST", "admin")
    report = app.reports.report("MANAGEMENT", {}, "auditor")
    assert len(report["digest"]) == 64
