import pytest


@pytest.mark.acceptance_alpha
def test_acceptance_alpha_bankschd(check_acceptance_alpha):
    check_acceptance_alpha("BANKSCHD")
