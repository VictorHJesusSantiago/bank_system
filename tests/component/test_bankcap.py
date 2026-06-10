import pytest


@pytest.mark.component
def test_component_bankcap(check_component_full_menu):
    check_component_full_menu("BANKCAP")
