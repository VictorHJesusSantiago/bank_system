import pytest


@pytest.mark.component
def test_component_bankcons(check_component_full_menu):
    check_component_full_menu("BANKCONS")
