import pytest


@pytest.mark.system
def test_system_bankcons(check_system_e2e):
    check_system_e2e("BANKCONS")
