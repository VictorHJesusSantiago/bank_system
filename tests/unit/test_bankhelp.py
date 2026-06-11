import pytest


@pytest.mark.unit
def test_unit_bankhelp(check_unit_menu_banner):
    check_unit_menu_banner("BANKHELP")
