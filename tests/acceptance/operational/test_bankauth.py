import pytest


@pytest.mark.acceptance_operational
def test_acceptance_operational_bankauth(check_acceptance_operational):
    check_acceptance_operational("BANKAUTH")
