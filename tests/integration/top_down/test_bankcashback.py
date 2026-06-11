import pytest


@pytest.mark.integration_top_down
def test_integration_top_down_bankcashback(check_integration_top_down):
    check_integration_top_down("BANKCASHBACK")
