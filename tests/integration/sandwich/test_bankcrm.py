import pytest


@pytest.mark.integration_sandwich
def test_integration_sandwich_bankcrm(check_integration_sandwich):
    check_integration_sandwich("BANKCRM")
