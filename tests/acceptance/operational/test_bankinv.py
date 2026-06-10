import pytest


@pytest.mark.acceptance_operational
def test_acceptance_operational_bankinv(check_acceptance_operational):
    check_acceptance_operational("BANKINV")
