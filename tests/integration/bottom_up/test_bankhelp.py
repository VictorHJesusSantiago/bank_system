import pytest


@pytest.mark.integration_bottom_up
def test_integration_bottom_up_bankhelp(check_integration_bottom_up):
    check_integration_bottom_up("BANKHELP")
