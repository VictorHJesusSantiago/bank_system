import pytest


@pytest.mark.acceptance_regulatory
def test_acceptance_regulatory_bankauth(check_acceptance_regulatory):
    check_acceptance_regulatory("BANKAUTH")
