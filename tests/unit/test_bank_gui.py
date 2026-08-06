import os

import pytest

import bank_gui as bg


@pytest.fixture
def app():
    return bg.BankGuiApp.__new__(bg.BankGuiApp)


@pytest.mark.unit
def test_windows_path_to_wsl(tmp_path):
    result = bg.windows_path_to_wsl(tmp_path)
    if os.name == "nt":
        assert result.startswith("/mnt/")
        assert "\\" not in result
    else:
        assert result == str(tmp_path.resolve())


@pytest.mark.unit
@pytest.mark.parametrize(
    "value, expected",
    [
        ("123.456-78", "12345678"),
        ("abc", ""),
        ("", ""),
    ],
)
def test_digits_only(app, value, expected):
    assert app._digits_only(value) == expected


@pytest.mark.unit
@pytest.mark.parametrize(
    "value, expected",
    [
        ("100", "100"),
        ("100.50", "100,50"),
        ("100,5", "100,5"),
        ("-50,00", "-50,00"),
        ("", None),
        ("abc", None),
    ],
)
def test_normalize_money(app, value, expected):
    assert app._normalize_money(value) == expected


@pytest.mark.unit
@pytest.mark.parametrize(
    "value, expected",
    [
        ("1234", "1234"),
        ("12-34", "1234"),
        ("", None),
    ],
)
def test_validate_account_number(app, value, expected):
    assert app._validate_account_number(value) == expected


@pytest.mark.unit
@pytest.mark.parametrize(
    "value, expected",
    [
        ("1234", "1234"),
        ("123", None),
        ("12345", None),
    ],
)
def test_validate_agency(app, value, expected):
    assert app._validate_agency(value) == expected


@pytest.mark.unit
@pytest.mark.parametrize(
    "value, expected",
    [
        ("123.456.789-09", "12345678909"),
        ("1234567890", None),
        ("123456789012", None),
    ],
)
def test_validate_cpf(app, value, expected):
    assert app._validate_cpf(value) == expected


@pytest.mark.unit
def test_build_command(app):
    command = app._build_command()
    assert command[:3] == ["wsl", "bash", "-lc"]
    assert "bankmain" in command[-1]
