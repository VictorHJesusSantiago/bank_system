import pytest


@pytest.mark.acceptance_operational
def test_acceptance_operational_bankpay(check_acceptance_operational):
    check_acceptance_operational("BANKPAY")
