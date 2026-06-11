import pytest


@pytest.mark.system
def test_system_bankcap(check_system_e2e):
    check_system_e2e("BANKCAP")
