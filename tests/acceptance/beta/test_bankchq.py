import pytest


@pytest.mark.acceptance_beta
def test_acceptance_beta_bankchq(check_acceptance_beta):
    check_acceptance_beta("BANKCHQ")
