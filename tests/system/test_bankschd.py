import pytest


@pytest.mark.system
def test_system_bankschd(check_system_e2e):
    check_system_e2e("BANKSCHD")
