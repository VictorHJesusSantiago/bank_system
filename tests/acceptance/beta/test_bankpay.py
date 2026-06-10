import pytest


@pytest.mark.acceptance_beta
def test_acceptance_beta_bankpay(check_acceptance_beta):
    check_acceptance_beta("BANKPAY")
