import pytest


@pytest.mark.integration_top_down
def test_integration_top_down_bankport(check_integration_top_down):
    check_integration_top_down("BANKPORT")
