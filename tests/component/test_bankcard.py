import pytest


@pytest.mark.component
def test_component_bankcard(check_component_full_menu):
    check_component_full_menu("BANKCARD")
