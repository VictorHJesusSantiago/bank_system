import pytest


@pytest.mark.acceptance_uat
def test_acceptance_uat_bankseg(check_acceptance_uat):
    check_acceptance_uat("BANKSEG")
