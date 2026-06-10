import pytest


@pytest.mark.acceptance_operational
def test_acceptance_operational_banktrf(check_acceptance_operational):
    check_acceptance_operational("BANKTRF")
