import pytest


@pytest.mark.integration_big_bang
def test_integration_big_bang_bankconsig(check_integration_big_bang):
    check_integration_big_bang("BANKCONSIG")
