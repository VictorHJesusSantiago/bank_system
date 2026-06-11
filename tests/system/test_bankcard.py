import pytest


@pytest.mark.system
def test_system_bankcard(check_system_e2e):
    check_system_e2e("BANKCARD")
