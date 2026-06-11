import pytest


@pytest.mark.system
def test_system_bankfgts(check_system_e2e):
    check_system_e2e("BANKFGTS")
