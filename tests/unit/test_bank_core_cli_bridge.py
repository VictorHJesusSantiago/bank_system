from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

from bank_core import BankingCore

CLI = str(Path(__file__).resolve().parents[2] / "bank_core_cli.py")


def run_cli(db_path, *args, cobol_out=None):
    cmd = [sys.executable, CLI, "--database", str(db_path)]
    if cobol_out:
        cmd += ["--cobol-out", str(cobol_out)]
    cmd += list(args)
    return subprocess.run(cmd, capture_output=True, text=True)


def read_cobol_out(path: Path) -> dict[str, str]:
    lines = path.read_text(encoding="ascii").splitlines()
    return dict(line.split("=", 1) for line in lines if "=" in line)


def test_cobol_out_written_on_success(tmp_path):
    db_path = tmp_path / "core.db"
    out_path = tmp_path / "out.txt"
    result = run_cli(db_path, "init", cobol_out=out_path)
    assert result.returncode == 0
    assert out_path.exists()
    fields = read_cobol_out(out_path)
    assert fields["OK"] == "1"


def test_cobol_out_written_on_domain_error(tmp_path):
    db_path = tmp_path / "core.db"
    out_path = tmp_path / "out.txt"
    run_cli(db_path, "init")
    result = run_cli(db_path, "account", "0000000001", cobol_out=out_path)
    assert result.returncode == 2
    fields = read_cobol_out(out_path)
    assert fields["OK"] == "0"
    assert "ERROR" in fields


def test_transfer_via_cli_flattens_transaction_id(tmp_path):
    db_path = tmp_path / "core.db"
    out_path = tmp_path / "out.txt"
    run_cli(db_path, "init")
    run_cli(db_path, "create-account", "0000000001", "11111111111", "--balance", "100.00")
    run_cli(db_path, "create-account", "0000000002", "22222222222")
    result = run_cli(
        db_path,
        "transfer",
        "0000000001",
        "0000000002",
        "10.00",
        "idem-1",
        cobol_out=out_path,
    )
    assert result.returncode == 0
    fields = read_cobol_out(out_path)
    assert fields["OK"] == "1"
    assert "TRANSACTION_ID" in fields

    core = BankingCore(db_path)
    assert core.ledger.account("0000000002")["ledger_balance"] == pytest.approx(10.00)


def test_migrate_isam_dump_is_idempotent(tmp_path):
    db_path = tmp_path / "core.db"
    dump_path = tmp_path / "BANKACCT.DUMP"
    dump_path.write_text(
        "CONTA|0000000010|33333333333|CC|A|1500,00\n"
        "TRANS|000000000000001|0000000010|0000000020|TED|10,00|E\n",
        encoding="ascii",
    )
    run_cli(db_path, "init")
    first = run_cli(db_path, "migrate-isam-dump", str(dump_path))
    assert first.returncode == 0
    second = run_cli(db_path, "migrate-isam-dump", str(dump_path))
    assert second.returncode == 0

    core = BankingCore(db_path)
    account = core.ledger.account("0000000010")
    assert account["ledger_balance"] == pytest.approx(1500.00)
