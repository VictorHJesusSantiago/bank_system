import pytest


@pytest.mark.acceptance_beta
def test_acceptance_beta_bankhelp(check_acceptance_beta):
    check_acceptance_beta("BANKHELP")
