import pytest


@pytest.mark.acceptance_operational
def test_acceptance_operational_bankcons(check_acceptance_operational):
    check_acceptance_operational("BANKCONS")
