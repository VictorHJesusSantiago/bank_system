import pytest


@pytest.mark.integration_big_bang
def test_integration_big_bang_bankport(check_integration_big_bang):
    check_integration_big_bang("BANKPORT")
