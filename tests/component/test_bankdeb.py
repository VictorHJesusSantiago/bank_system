import pytest


@pytest.mark.component
def test_component_bankdeb(check_component_full_menu):
    check_component_full_menu("BANKDEB")
