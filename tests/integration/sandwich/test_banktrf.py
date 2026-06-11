import pytest


@pytest.mark.integration_sandwich
def test_integration_sandwich_banktrf(check_integration_sandwich):
    check_integration_sandwich("BANKTRF")
