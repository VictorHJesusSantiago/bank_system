import pytest


@pytest.mark.system
def test_system_bankdeb(check_system_e2e):
    check_system_e2e("BANKDEB")
