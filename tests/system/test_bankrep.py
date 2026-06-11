import pytest


@pytest.mark.system
def test_system_bankrep(check_system_e2e):
    check_system_e2e("BANKREP")
