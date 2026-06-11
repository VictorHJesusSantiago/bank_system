import pytest


@pytest.mark.integration_top_down
def test_integration_top_down_bankreneg(check_integration_top_down):
    check_integration_top_down("BANKRENEG")
