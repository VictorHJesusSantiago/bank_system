import pytest


@pytest.mark.integration_sandwich
def test_integration_sandwich_bankinv(check_integration_sandwich):
    check_integration_sandwich("BANKINV")
