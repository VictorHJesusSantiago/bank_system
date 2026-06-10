import pytest


@pytest.mark.acceptance_beta
def test_acceptance_beta_bankqry(check_acceptance_beta):
    check_acceptance_beta("BANKQRY")
