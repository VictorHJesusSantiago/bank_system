import pytest


@pytest.mark.acceptance_regulatory
def test_acceptance_regulatory_bankchq(check_acceptance_regulatory):
    check_acceptance_regulatory("BANKCHQ")
