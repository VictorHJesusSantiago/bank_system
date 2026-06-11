import pytest


@pytest.mark.integration_top_down
def test_integration_top_down_bankadm(check_integration_top_down):
    check_integration_top_down("BANKADM")
