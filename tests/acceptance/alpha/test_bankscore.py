import pytest


@pytest.mark.acceptance_alpha
def test_acceptance_alpha_bankscore(check_acceptance_alpha):
    check_acceptance_alpha("BANKSCORE")
