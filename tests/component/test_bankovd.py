import pytest


@pytest.mark.component
def test_component_bankovd(check_component_full_menu):
    check_component_full_menu("BANKOVD")
