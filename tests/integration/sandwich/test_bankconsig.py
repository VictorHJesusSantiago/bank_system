import pytest


@pytest.mark.integration_sandwich
def test_integration_sandwich_bankconsig(check_integration_sandwich):
    check_integration_sandwich("BANKCONSIG")
