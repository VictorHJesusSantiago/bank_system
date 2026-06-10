import pytest


@pytest.mark.component
def test_component_bankcob(check_component_full_menu):
    check_component_full_menu("BANKCOB")
