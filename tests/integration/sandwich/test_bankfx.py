import pytest


@pytest.mark.integration_sandwich
def test_integration_sandwich_bankfx(check_integration_sandwich):
    check_integration_sandwich("BANKFX")
