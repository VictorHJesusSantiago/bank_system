import pytest


@pytest.mark.acceptance_uat
def test_acceptance_uat_bankcons(check_acceptance_uat):
    check_acceptance_uat("BANKCONS")
