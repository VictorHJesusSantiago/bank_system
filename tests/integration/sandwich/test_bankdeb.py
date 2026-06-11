import pytest


@pytest.mark.integration_sandwich
def test_integration_sandwich_bankdeb(check_integration_sandwich):
    check_integration_sandwich("BANKDEB")
