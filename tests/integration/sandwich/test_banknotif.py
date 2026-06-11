import pytest


@pytest.mark.integration_sandwich
def test_integration_sandwich_banknotif(check_integration_sandwich):
    check_integration_sandwich("BANKNOTIF")
