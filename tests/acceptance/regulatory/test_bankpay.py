import pytest


@pytest.mark.acceptance_regulatory
def test_acceptance_regulatory_bankpay(check_acceptance_regulatory):
    check_acceptance_regulatory("BANKPAY")
