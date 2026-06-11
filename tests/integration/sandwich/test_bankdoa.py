import pytest


@pytest.mark.integration_sandwich
def test_integration_sandwich_bankdoa(check_integration_sandwich):
    check_integration_sandwich("BANKDOA")
