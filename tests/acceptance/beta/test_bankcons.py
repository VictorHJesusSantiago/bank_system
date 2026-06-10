import pytest


@pytest.mark.acceptance_beta
def test_acceptance_beta_bankcons(check_acceptance_beta):
    check_acceptance_beta("BANKCONS")
