import pytest


@pytest.mark.integration_top_down
def test_integration_top_down_bankprev(check_integration_top_down):
    check_integration_top_down("BANKPREV")
