import pytest


@pytest.mark.acceptance_regulatory
def test_acceptance_regulatory_bankreneg(check_acceptance_regulatory):
    check_acceptance_regulatory("BANKRENEG")
