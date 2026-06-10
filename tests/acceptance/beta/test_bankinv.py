import pytest


@pytest.mark.acceptance_beta
def test_acceptance_beta_bankinv(check_acceptance_beta):
    check_acceptance_beta("BANKINV")
