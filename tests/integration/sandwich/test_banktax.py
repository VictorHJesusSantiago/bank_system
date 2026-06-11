import pytest


@pytest.mark.integration_sandwich
def test_integration_sandwich_banktax(check_integration_sandwich):
    check_integration_sandwich("BANKTAX")
