from decimal import Decimal

import pytest

from bank_core import AuthorizationError, BankDatabase, LedgerService
from bank_openfinance import OpenFinanceAPI, OpenFinanceService


@pytest.fixture
def setup(tmp_path):
    db = BankDatabase(tmp_path / "of.db")
    ledger = LedgerService(db)
    ledger.create_account("1001", "user-1", initial_balance="1000")
    ledger.create_account("1002", "user-2", initial_balance="100")
    service = OpenFinanceService(db, ledger)
    client = service.create_client(
        "Fintech",
        {
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
        },
    )
    return service, ledger, client


def authorised(service, client, scopes):
    consent = service.create_consent("user-1", client["client_id"], set(scopes))
    service.authenticate_consent(consent, "user-1")
    service.confirm_consent(consent, "user-1")
    return consent


def test_consent_auth_confirmation_history_and_revocation(setup):
    service, _, client = setup
    consent = authorised(service, client, {"ACCOUNTS_READ"})
    assert [row["state"] for row in service.history(consent)] == [
        "AWAITING_AUTHENTICATION",
        "AWAITING_CONFIRMATION",
        "AUTHORISED",
    ]
    service.revoke_consent(consent, "user-1")
    with pytest.raises(AuthorizationError):
        service.consent(consent, "ACCOUNTS_READ", client["client_id"])


def test_share_accounts_transactions_and_product_domains(setup):
    service, ledger, client = setup
    ledger.transfer("1001", "1002", "10", "of-test-transfer")
    consent = authorised(service, client, {"ACCOUNTS_READ", "TRANSACTIONS_READ", "CARDS_READ"})
    assert (
        service.share(consent, client["client_id"], "ACCOUNTS_READ", "corr")["data"][0]["account_number"]
        == "1001"
    )
    assert service.share(consent, client["client_id"], "TRANSACTIONS_READ", "corr")["data"]
    service.import_external("user-1", "Banco Externo", "CARD", [{"last4": "1234", "limit_cents": 50000}])
    assert (
        service.share(consent, client["client_id"], "CARDS_READ", "corr")["data"][0]["payload"]["last4"]
        == "1234"
    )


def test_external_import_aggregator_and_multibank_view(setup):
    service, _, _ = setup
    service.import_external(
        "user-1", "Outro Banco", "ACCOUNT", [{"account": "ext-1", "balance_cents": 25000, "currency": "BRL"}]
    )
    service.import_external("user-1", "Corretora", "INVESTMENT", [{"value_cents": 30000}])
    result = service.aggregate("user-1")
    assert len(result["balances"]) == 2
    assert result["total_brl_cents"] == 125000
    assert result["products"]["INVESTMENT"][0]["institution"] == "Corretora"


def test_payment_initiation_idempotency_and_credit_proposal(setup):
    service, ledger, client = setup
    consent = authorised(service, client, {"PAYMENTS_INITIATE", "CREDIT_PROPOSAL_CREATE"})
    first = service.initiate_payment(consent, client["client_id"], "idem-1", "1001", "1002", "20")
    second = service.initiate_payment(consent, client["client_id"], "idem-1", "1001", "1002", "20")
    assert first == second
    assert ledger.account("1002")["ledger_balance"] == Decimal("120.00")
    assert service.credit_proposal(consent, client["client_id"], "5000", 24, "Veículo")


def test_certificate_signatures(setup):
    service, _, _ = setup
    certificate = service.issue_certificate()
    payload = b'{"message":"sandbox"}'
    signature = service.sign(certificate["certificate_id"], payload)
    assert service.verify(certificate["certificate_id"], payload, signature)
    assert not service.verify(certificate["certificate_id"], b"changed", signature)


def test_client_authentication_rate_limit(setup):
    service, _, _ = setup
    client = service.create_client("Limited", {"ACCOUNTS_READ"}, rate_limit=1)
    service.authenticate_client(client["client_id"], client["client_secret"])
    with pytest.raises(AuthorizationError):
        service.authenticate_client(client["client_id"], client["client_secret"])


def test_http_application_openapi_health_auth_and_errors(setup):
    service, _, client = setup
    api = OpenFinanceAPI(service)
    assert api.handle("GET", "/health", {}, None)[0] == 200
    assert api.handle("GET", "/openapi.json", {}, None)[1]["openapi"] == "3.1.0"
    headers = {
        "X-Client-ID": client["client_id"],
        "X-Client-Secret": client["client_secret"],
        "X-Correlation-ID": "corr-1",
    }
    status, payload = api.handle(
        "POST", "/open-finance/consents", headers, {"user_id": "user-1", "scopes": ["ACCOUNTS_READ"]}
    )
    assert status == 201 and payload["correlation_id"] == "corr-1"
    assert api.handle("GET", "/unknown", headers, None)[0] == 404


def test_synthetic_data_and_access_trace(setup):
    service, _, client = setup
    assert service.synthetic_data(7) == service.synthetic_data(7)
    consent = authorised(service, client, {"ACCOUNTS_READ"})
    service.share(consent, client["client_id"], "ACCOUNTS_READ", "trace-1")
    with service.db.connect() as con:
        row = con.execute("SELECT * FROM of_access_logs WHERE correlation_id='trace-1'").fetchone()
    assert row["result"] == "SUCCESS" and row["scope"] == "ACCOUNTS_READ"
