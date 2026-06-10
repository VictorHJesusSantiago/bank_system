import pytest


@pytest.mark.acceptance_alpha
def test_acceptance_alpha_bankdeb(check_acceptance_alpha):
    check_acceptance_alpha("BANKDEB")
