import pytest


@pytest.mark.acceptance_regulatory
def test_acceptance_regulatory_bankovd(check_acceptance_regulatory):
    check_acceptance_regulatory("BANKOVD")
