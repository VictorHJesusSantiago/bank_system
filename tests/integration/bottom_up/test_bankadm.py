import pytest


@pytest.mark.integration_bottom_up
def test_integration_bottom_up_bankadm(check_integration_bottom_up):
    check_integration_bottom_up("BANKADM")
