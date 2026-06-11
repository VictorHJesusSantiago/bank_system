import pytest


@pytest.mark.integration_top_down
def test_integration_top_down_bankcob(check_integration_top_down):
    check_integration_top_down("BANKCOB")
