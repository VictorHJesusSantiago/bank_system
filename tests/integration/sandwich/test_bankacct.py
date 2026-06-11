import pytest


@pytest.mark.integration_sandwich
def test_integration_sandwich_bankacct(check_integration_sandwich):
    check_integration_sandwich("BANKACCT")
