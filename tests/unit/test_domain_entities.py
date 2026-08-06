"""Entidades de domínio Account e Hold.

O valor de tirar a regra do serviço é este arquivo: as invariantes de saldo e
reserva passam a ser testáveis sem banco, sem transação e sem fixture.
"""

import dataclasses

import pytest

from bank_core import Account, AccountingError, Hold, Money


def conta(**overrides) -> Account:
    base = dict(
        account_number="1001",
        owner_id="dono",
        kind="CC",
        status="ACTIVE",
        currency="BRL",
        ledger_balance_cents=10_000,
        blocked_balance_cents=0,
        projected_balance_cents=10_000,
        overdraft_limit_cents=0,
        version=1,
    )
    return Account(**{**base, **overrides})


def test_available_subtracts_blocked_and_adds_overdraft():
    account = conta(ledger_balance_cents=10_000, blocked_balance_cents=3_000, overdraft_limit_cents=5_000)
    assert account.available_cents == 12_000
    assert account.available == Money.from_cents(12_000)


def test_debit_within_available_is_allowed():
    conta(overdraft_limit_cents=5_000).ensure_can_apply(-14_000)


def test_debit_beyond_available_is_refused():
    with pytest.raises(AccountingError) as exc:
        conta(overdraft_limit_cents=5_000).ensure_can_apply(-15_001)
    assert exc.value.code == "INSUFFICIENT_FUNDS"


def test_blocked_balance_is_not_spendable():
    with pytest.raises(AccountingError):
        conta(blocked_balance_cents=10_000).ensure_can_apply(-1)


def test_inactive_account_refuses_any_movement():
    for status in ("BLOCKED", "CLOSED"):
        with pytest.raises(AccountingError) as exc:
            conta(status=status).ensure_can_apply(1_000)
        assert exc.value.code == "ACCOUNT_BLOCKED"


def test_credit_into_negative_account_is_allowed():
    conta(ledger_balance_cents=-5_000).ensure_can_apply(1_000)


def test_hold_requires_available_balance():
    conta().ensure_can_hold(10_000)
    with pytest.raises(AccountingError) as exc:
        conta().ensure_can_hold(10_001)
    assert exc.value.code == "INSUFFICIENT_FUNDS"


def test_capture_sees_its_own_reservation_but_not_other_blocks():
    """Regra sutil que estava embutida no serviço e divergia das outras três."""
    account = conta(ledger_balance_cents=10_000, blocked_balance_cents=8_000)
    assert account.available_cents == 2_000
    assert account.available_for_capture_cents(6_000) == 8_000


def test_hold_remaining_and_terminal_state():
    hold = Hold(
        "h1", "1001", amount_cents=5_000, captured_cents=2_000, state="ACTIVE", reason="pré-autorização"
    )
    assert hold.remaining_cents == 3_000 and hold.is_active
    assert hold.state_after_capturing(3_000) == "CAPTURED"
    assert hold.state_after_capturing(1_000) == "ACTIVE"


def test_hold_refuses_overcapture_and_nonpositive():
    hold = Hold("h1", "1001", 5_000, 2_000, "ACTIVE", "reserva")
    hold.ensure_capturable(3_000)
    for invalid in (0, -1, 3_001):
        with pytest.raises(AccountingError) as exc:
            hold.ensure_capturable(invalid)
        assert exc.value.code == "INVALID_CAPTURE"


def test_account_is_immutable():
    with pytest.raises(dataclasses.FrozenInstanceError):
        conta().ledger_balance_cents = 999_999


def test_dict_projection_keeps_the_public_contract():
    """CLI, GUI e testes existentes consomem o dicionário; não pode regredir."""
    projection = conta(blocked_balance_cents=1_000, overdraft_limit_cents=2_000).as_dict()
    assert projection["available_balance"] == Money.from_cents(11_000).amount
    assert projection["ledger_balance_cents"] == 10_000
    assert {"account_number", "status", "version", "projected_balance"} <= set(projection)
