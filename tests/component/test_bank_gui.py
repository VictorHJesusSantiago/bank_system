import tkinter as tk

import pytest

import bank_gui as bg


@pytest.fixture
def app():
    try:
        root = tk.Tk()
        root.withdraw()
    except tk.TclError:
        pytest.skip("ambiente sem display grafico (Tk indisponivel)")

    instance = bg.BankGuiApp.__new__(bg.BankGuiApp)
    instance._mask_updating = False
    instance.open_cpf_var = tk.StringVar()
    instance.open_telefone_var = tk.StringVar()
    instance.dep_valor_var = tk.StringVar()
    yield instance
    root.destroy()


@pytest.mark.component
def test_mask_cpf_var(app):
    app.open_cpf_var.set("12345678909")
    app._mask_cpf_var()
    assert app.open_cpf_var.get() == "123.456.789-09"


@pytest.mark.component
def test_mask_phone_var(app):
    app.open_telefone_var.set("11987654321")
    app._mask_phone_var()
    assert app.open_telefone_var.get() == "(11) 98765-4321"


@pytest.mark.component
def test_mask_money_var(app):
    app.dep_valor_var.set("10050")
    app._mask_money_var(app.dep_valor_var)
    assert app.dep_valor_var.get() == "100,50"
