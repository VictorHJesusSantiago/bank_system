import pytest


@pytest.mark.acceptance_regulatory
def test_acceptance_regulatory_bankadm(check_acceptance_regulatory):
    check_acceptance_regulatory("BANKADM")
