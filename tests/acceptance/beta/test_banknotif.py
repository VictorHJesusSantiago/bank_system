import pytest


@pytest.mark.acceptance_beta
def test_acceptance_beta_banknotif(check_acceptance_beta):
    check_acceptance_beta("BANKNOTIF")
