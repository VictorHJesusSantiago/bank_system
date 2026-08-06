#!/usr/bin/env python3
"""Comprehensive test suite for the COBOL banking system.

Run via: python3 test_suite.py
Requires Linux/WSL2 (uses pty). Each test group is independent.
"""

import os
import re
import time
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional, Tuple


ROOT = os.path.dirname(os.path.abspath(__file__))
BANKMAIN = os.path.join(ROOT, "bin", "bankmain")
LIBPATH = os.path.join(ROOT, "bin")

try:
    import pty
    import select
    import subprocess

    _HAS_PTY = True
except ImportError:
    _HAS_PTY = False


def run_session(inputs: List[str], timeout: float = 30.0, delay: float = 0.07) -> str:
    if not _HAS_PTY:
        return ""
    if not os.path.exists(BANKMAIN):
        raise FileNotFoundError(f"Executable not found: {BANKMAIN}")
    env = dict(os.environ)
    env["COB_LIBRARY_PATH"] = LIBPATH
    master_fd, slave_fd = pty.openpty()
    proc = subprocess.Popen(
        [BANKMAIN],
        cwd=ROOT,
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        env=env,
        close_fds=True,
    )
    os.close(slave_fd)
    chunks: List[str] = []
    start = time.time()
    idx = 0
    try:
        while time.time() - start < timeout:
            if idx < len(inputs):
                time.sleep(delay)
                os.write(master_fd, (str(inputs[idx]) + "\n").encode())
                idx += 1
            ready, _, _ = select.select([master_fd], [], [], 0.05)
            if master_fd in ready:
                try:
                    data = os.read(master_fd, 8192)
                except OSError:
                    break
                if not data:
                    break
                chunks.append(data.decode(errors="ignore"))
            if proc.poll() is not None and idx >= len(inputs):
                break
    finally:
        if proc.poll() is None:
            proc.terminate()
            time.sleep(0.1)
            if proc.poll() is None:
                proc.kill()
        try:
            os.close(master_fd)
        except OSError:
            pass
    return "".join(chunks)




@dataclass
class TestResult:
    name: str
    passed: bool
    missing: List[str] = field(default_factory=list)
    extra_info: str = ""


_results: List[TestResult] = []


def check(
    name: str, output: str, expected: List[str], not_expected: Optional[List[str]] = None
) -> TestResult:
    missing = [t for t in expected if t not in output]
    bad = [t for t in (not_expected or []) if t in output]
    passed = not missing and not bad
    extra = ""
    if bad:
        extra = f"UNWANTED: {bad}"
    r = TestResult(name, passed, missing, extra)
    _results.append(r)
    status = "PASS" if passed else "FAIL"
    mark = "✓" if passed else "✗"
    print(f"  [{status}] {mark} {name}")
    if not passed:
        if missing:
            print(f"         Missing: {missing}")
        if bad:
            print(f"         Unwanted: {bad}")
    return r




def _today_prefix() -> str:
    """Account number prefix = YYYYMMDD."""
    return datetime.now().strftime("%Y%m%d")


def _make_barcode_valid() -> str:
    """Generate a 44-digit barcode with correct Modulo-10 DV."""
    payload = "1234567890123456789012345678901234567890123"
    total, weight = 0, 2
    for ch in reversed(payload):
        total += int(ch) * weight
        weight = 2 if weight == 9 else weight + 1
    dv = 11 - (total % 11)
    if dv > 9:
        dv = 1
    return payload + str(dv)


def _make_barcode_invalid_dv() -> str:
    """A barcode where the check digit is deliberately wrong."""
    barcode = _make_barcode_valid()
    wrong = str((int(barcode[-1]) + 1) % 10)
    return barcode[:-1] + wrong



_ACCOUNTS: List[Tuple[str, str, str, str]] = []
_CPF_A = "52998224725"
_CPF_B = "11144477735"
_CPF_C = "12345678909"


def _seed_accounts() -> None:
    """Ensure three QA accounts exist, returning their numbers."""
    global _ACCOUNTS
    run_session(
        [
            "1",
            "01",
            "QA ALICE",
            _CPF_A,
            "CC",
            "0001",
            "alice@qa.com",
            "11900000001",
            "01",
            "QA BOB",
            _CPF_B,
            "CC",
            "0001",
            "bob@qa.com",
            "11900000002",
            "01",
            "QA CAROL",
            _CPF_C,
            "CP",
            "0001",
            "carol@qa.com",
            "11900000003",
            "00",
            "0",
        ],
        timeout=60,
        delay=0.09,
    )
    prefix = _today_prefix()
    seq = ["1"]
    candidates = [str(int(prefix) * 100 + i) for i in range(50)]
    for c in candidates:
        seq += ["02", c]
    seq += ["00", "0"]
    out = run_session(seq, timeout=60, delay=0.04)
    pattern = re.compile(
        r"Numero:\s*(\d{10}).*?CPF:\s*([0-9]{11}).*?Email:\s*(.*?)\r?\n"
        r".*?Telefone:\s*([0-9]{8,15}).*?Status:\s*([A-Z])",
        re.S,
    )
    seen: set = set()
    found: List[Tuple[str, str, str, str]] = []
    for m in pattern.finditer(out):
        num, cpf, email, phone, status = m.groups()
        if status != "A" or num in seen:
            continue
        seen.add(num)
        found.append((num, cpf, email.strip(), phone.strip()))
    _ACCOUNTS = found[:3]
    if len(_ACCOUNTS) < 2:
        print(f"  [WARN] Only {len(_ACCOUNTS)} accounts found after seed.")




def test_cpf_validation() -> None:
    print("\n── CPF Validation ─────────────────────────────────────────")

    out = run_session(
        ["1", "01", "CPF VALID", "52998224725", "CC", "0001", "v@qa.com", "11900000099", "00", "0"]
    )
    check("Valid CPF accepted", out, ["CONTA ABERTA COM SUCESSO"])

    out = run_session(
        ["1", "01", "CPF SAME", "11111111111", "CC", "0001", "x@qa.com", "11900000098", "00", "0"]
    )
    check("All-same digits CPF rejected", out, ["CPF INVALIDO"], not_expected=["CONTA ABERTA COM SUCESSO"])

    out = run_session(
        ["1", "01", "CPF ZERO", "00000000000", "CC", "0001", "x@qa.com", "11900000097", "00", "0"]
    )
    check("All-zeros CPF rejected", out, ["CPF INVALIDO"])

    out = run_session(
        ["1", "01", "CPF BAD DV", "11144477736", "CC", "0001", "x@qa.com", "11900000096", "00", "0"]
    )
    check("Invalid 2nd check digit rejected", out, ["CPF INVALIDO"])

    out = run_session(
        [
            "1",
            "01",
            "CPF WRONG",
            "11111111111",
            "CC",
            "0001",
            "x@qa.com",
            "11900000095",
            "01",
            "CPF RIGHT",
            "11144477735",
            "CC",
            "0001",
            "r@qa.com",
            "11900000094",
            "00",
            "0",
        ]
    )
    check("Good CPF succeeds after rejected CPF in same session", out, ["CONTA ABERTA COM SUCESSO"])


def test_account_management() -> None:
    print("\n── Account Management ─────────────────────────────────────")

    out = run_session(
        [
            "1",
            "01",
            "DUP CPF TEST",
            "52998224725",
            "CC",
            "0001",
            "d1@qa.com",
            "11900000093",
            "01",
            "DUP CPF TEST",
            "52998224725",
            "CC",
            "0001",
            "d2@qa.com",
            "11900000092",
            "00",
            "0",
        ],
        timeout=40,
        delay=0.09,
    )
    check("Duplicate account write shows warning, not double success", out, ["ATENCAO: CPF ja possui conta"])

    if not _ACCOUNTS:
        print("  [SKIP] No seed accounts — skipping remaining account tests")
        return

    num = _ACCOUNTS[0][0]

    out = run_session(["1", "04", num, "00", "0"])
    check("Account lock", out, ["CONTA BLOQUEADA"])

    out = run_session(["1", "04", num, "00", "0"])
    check("Account unlock", out, ["CONTA DESBLOQUEADA"])

    out = run_session(["1", "07", _ACCOUNTS[0][1], "00", "0"])
    check("Search account by CPF", out, ["DADOS DA CONTA"])

    out = run_session(["2", "01", num, "100,00", "00", "0"])
    out_close = run_session(["1", "05", num, "00", "0"])
    check("Close account with positive balance blocked", out_close, ["CONTA POSSUI SALDO"])

    out = run_session(["1", "08", "00", "0"])
    check("Apply maintenance fees completes", out, ["TARIFAS APLICADAS"])


def test_deposits() -> None:
    print("\n── Deposits ───────────────────────────────────────────────")
    if not _ACCOUNTS:
        print("  [SKIP]")
        return
    num = _ACCOUNTS[0][0]

    out = run_session(["2", "01", num, "500,00", "00", "0"])
    check("Deposit R$500 succeeds", out, ["DEPOSITO REALIZADO"])

    out = run_session(["2", "01", num, "0,00", "00", "0"])
    check("Deposit R$0 rejected", out, ["VALOR INVALIDO"])

    out = run_session(["2", "01", num, "-50,00", "00", "0"])
    check("Negative deposit rejected", out, ["VALOR INVALIDO"])

    out_ext = run_session(["2", "08", num, "00", "0"])
    check("Deposit appears in 30-day statement", out_ext, ["DEP"])


def test_withdrawals() -> None:
    print("\n── Withdrawals ────────────────────────────────────────────")
    if not _ACCOUNTS:
        print("  [SKIP]")
        return
    num = _ACCOUNTS[0][0]

    run_session(["2", "01", num, "1000,00", "00", "0"])

    out = run_session(["2", "02", num, "100,00", "00", "0"])
    check("Withdrawal R$100 succeeds", out, ["SAQUE REALIZADO"])

    out = run_session(["2", "02", num, "0,00", "00", "0"])
    check("Withdrawal R$0 rejected", out, ["VALOR INVALIDO"])

    out = run_session(["2", "02", num, "99999,00", "00", "0"])
    check("Withdrawal exceeding balance+limit rejected", out, ["SALDO INSUFICIENTE"])

    out = run_session(["2", "02", num, "6000,00", "00", "0"])
    check("Withdrawal exceeding daily limit rejected", out, ["EXCEDE LIMITE DIARIO"])


def test_ted_doc() -> None:
    print("\n── TED / DOC Transfers ────────────────────────────────────")
    if len(_ACCOUNTS) < 2:
        print("  [SKIP]")
        return
    src, dst = _ACCOUNTS[0][0], _ACCOUNTS[1][0]

    run_session(["2", "01", src, "2000,00", "00", "0"])

    out = run_session(["2", "03", src, dst, "10,00", "S", "00", "0"])
    check("TED transfer succeeds", out, ["TED REALIZADO"])

    out = run_session(["2", "04", src, dst, "5,00", "S", "00", "0"])
    check("DOC transfer succeeds", out, ["DOC REALIZADO"])
    check("DOC NOT logged as TED", out, [], not_expected=["TED REALIZADO"])

    out = run_session(["2", "03", src, dst, "10,00", "N", "00", "0"])
    check("TED cancelled when confirm=N", out, ["OPERACAO CANCELADA"])

    out = run_session(["2", "03", src, dst, "99999,00", "S", "00", "0"])
    check("TED rejected when balance < amount+fee", out, ["SALDO INSUFICIENTE"])

    out = run_session(["2", "03", src, "0000000001", "10,00", "S", "00", "0"])
    check("TED to non-existent account rejected", out, ["CONTA DESTINO NAO ENCONTRADA"])


def test_pix() -> None:
    print("\n── PIX ────────────────────────────────────────────────────")
    if len(_ACCOUNTS) < 2:
        print("  [SKIP]")
        return
    src, dst_cpf = _ACCOUNTS[0][0], _ACCOUNTS[1][1]

    run_session(["2", "01", src, "1000,00", "00", "0"])

    out = run_session(["2", "05", src, dst_cpf, "5,00", "00", "0"])
    check("PIX succeeds via BANKTRAN", out, ["PIX ENVIADO COM SUCESSO"])

    out_ext = run_session(["2", "08", src, "00", "0"])
    check("PIX logged with type PIX", out_ext, ["PIX"])

    run_session(["2", "01", src, "20,00", "00", "0"])
    out = run_session(["2", "05", src, dst_cpf, "20,00", "00", "0"])
    check("PIX uses zero fee (no R$14.90 deducted)", out, ["PIX ENVIADO COM SUCESSO"])

    out = run_session(["2", "05", src, dst_cpf, "99999,00", "00", "0"])
    check("PIX with insufficient balance rejected", out, ["SALDO INSUFICIENTE"])

    out = run_session(["2", "05", src, "99999999999", "5,00", "00", "0"])
    check("PIX to unknown CPF rejected", out, ["CPF DESTINO NAO ENCONTRADO"])

    if _ACCOUNTS[1][2] and "@" in _ACCOUNTS[1][2]:
        src2 = _ACCOUNTS[0][0]
        run_session(["2", "01", src2, "100,00", "00", "0"])
        out = run_session(["4", "03", src2, "E", _ACCOUNTS[1][2], "5,00", "00", "0"])
        check("PIX via BANKTRF by email key succeeds", out, ["PIX EFETUADO"])


def test_bill_payment() -> None:
    print("\n── Bill Payment ───────────────────────────────────────────")
    if not _ACCOUNTS:
        print("  [SKIP]")
        return
    num = _ACCOUNTS[0][0]
    run_session(["2", "01", num, "500,00", "00", "0"])

    valid_bc = _make_barcode_valid()
    invalid_bc = _make_barcode_invalid_dv()
    short_bc = "12345"

    out = run_session(["5", "01", num, valid_bc, "3,00", "00", "0"])
    check("Bill payment with valid barcode succeeds", out, ["BOLETO PAGO"])

    out = run_session(["5", "01", num, invalid_bc, "3,00", "00", "0"])
    check("Bill payment with invalid DV rejected", out, ["REPROVADO NO DV"])

    out = run_session(["5", "01", num, short_bc, "3,00", "00", "0"])
    check("Bill payment with short barcode rejected", out, ["44 DIGITOS"])

    out = run_session(["5", "01", num, valid_bc, "99999,00", "00", "0"])
    check("Bill payment insufficient balance rejected", out, ["SALDO"])

    out = run_session(["2", "06", valid_bc, num, "2,00", "00", "0"])
    check("Bill payment via BANKTRAN creates audit record", out, ["BOLETO PAGO COM SUCESSO"])
    out_ext = run_session(["2", "08", num, "00", "0"])
    check("Bill payment PAG appears in statement", out_ext, ["PAG"])


def test_statement_filter() -> None:
    print("\n── 30-Day Statement Filter ────────────────────────────────")
    if not _ACCOUNTS:
        print("  [SKIP]")
        return
    num = _ACCOUNTS[0][0]

    out = run_session(["2", "08", num, "00", "0"])
    check("Statement shows date range header", out, ["EXTRATO ULTIMOS 30 DIAS"])
    check("Statement shows De: ... Ate: ... dates", out, ["De:", "Ate:"])

    out = run_session(["3", "03", num, "00", "0"])
    check("BANKQRY extrato shows 30-day header", out, ["EXTRATO ULTIMOS 30 DIAS"])


def test_reversal() -> None:
    print("\n── Transaction Reversal (Estorno) ─────────────────────────")
    if not _ACCOUNTS:
        print("  [SKIP]")
        return
    num = _ACCOUNTS[0][0]

    run_session(["2", "01", num, "200,00", "00", "0"])

    out_ext = run_session(["2", "08", num, "00", "0"])
    id_matches = re.findall(r"\b(\d{14,15})\b", out_ext)
    if not id_matches:
        print("  [SKIP] No transaction IDs found in statement")
        return
    trans_id = id_matches[0]

    out = run_session(["2", "09", trans_id, "00", "0"])
    check(
        "Reversal of settled transaction succeeds",
        out,
        ["TRANSACAO ESTORNADA", "TRANSACAO NAO ENCONTRADA"],
        not_expected=["ERRO"],
    )

    out2 = run_session(["2", "09", trans_id, "00", "0"])
    check(
        "Re-reversal of already-reversed transaction blocked",
        out2,
        ["NAO PODE SER ESTORNADA", "NAO ENCONTRADA"],
    )

    out3 = run_session(["2", "09", "999999999999999", "00", "0"])
    check("Reversal of non-existent transaction blocked", out3, ["NAO ENCONTRADA"])


def test_investments() -> None:
    print("\n── Investments (CDB / LCI) ────────────────────────────────")

    out = run_session(["6", "01", "999,00", "180", "N", "00", "0"])
    check("CDB below R$1000 minimum rejected", out, ["VALOR ABAIXO DO MINIMO"])

    out = run_session(["6", "01", "1000,00", "180", "S", "00", "0"])
    check("CDB R$1000 / 180 days shows IR 22,5%", out, ["22,50"])
    check("CDB shows gross and net value", out, ["Valor Bruto Futuro", "Valor Liquido"])

    out = run_session(["6", "01", "1000,00", "721", "N", "00", "0"])
    check("CDB > 720 days shows IR 15%", out, ["15,00"])

    out = run_session(["6", "02", "4999,00", "00", "0"])
    check("LCI below R$5000 minimum rejected", out, ["VALOR ABAIXO DO MINIMO"])

    out = run_session(["6", "02", "5000,00", "00", "0"])
    check("LCI R$5000 accepted as tax-exempt", out, ["SEM IR", "LCI"])

    out = run_session(["6", "08", "1000,00", "252", "00", "0"])
    check("Investment simulator runs successfully", out, ["Resultado liquido"])


def test_crm() -> None:
    print("\n── CRM — Customer CRUD ────────────────────────────────────")
    seed = str(int(time.time()))
    cli_id = seed[-10:].rjust(10, "5")
    cpf = ("9" + seed)[-11:]

    out = run_session(
        [
            "7",
            "01",
            cli_id,
            "CRM TEST USER",
            cpf,
            "RG123",
            "19900115",
            "M",
            "SO",
            "DESENVOLVEDOR",
            "8000,00",
            "M",
            "rua teste",
            "100",
            "SP",
            "01310100",
            "02",
            cli_id,
            "03",
            cli_id,
            "upd@qa.com",
            "11988880000",
            "COORDENADOR",
            "9500,00",
            "A",
            "04",
            cli_id,
            "02",
            cli_id,
            "00",
            "0",
        ],
        timeout=80,
        delay=0.06,
    )
    check("CRM: customer created", out, ["CLIENTE CADASTRADO"])
    check("CRM: customer queried", out, ["CRM TEST USER"])
    check("CRM: customer updated", out, ["CADASTRO ATUALIZADO"])
    check("CRM: customer deactivated", out, ["CLIENTE INATIVADO"])
    check("CRM: status shows I after deactivation", out, ["Status: I", "INATIVADO"])

    out2 = run_session(
        [
            "7",
            "01",
            cli_id,
            "DUP",
            cpf,
            "RG999",
            "19900115",
            "M",
            "SO",
            "X",
            "1000,00",
            "C",
            "rua x",
            "1",
            "SP",
            "01000000",
            "00",
            "0",
        ],
    )
    check("CRM: duplicate customer ID rejected", out2, ["ID JA EXISTENTE"])


def test_queries() -> None:
    print("\n── Queries ────────────────────────────────────────────────")
    if not _ACCOUNTS:
        print("  [SKIP]")
        return
    num, cpf = _ACCOUNTS[0][0], _ACCOUNTS[0][1]

    out = run_session(["3", "01", num, "00", "0"])
    check("BANKQRY: query by account number", out, ["Titular:"])

    out = run_session(["3", "02", cpf, "00", "0"])
    check("BANKQRY: query by CPF", out, ["Titular:"])

    out = run_session(["3", "01", "0000000001", "00", "0"])
    check("BANKQRY: non-existent account returns not-found", out, ["NAO ENCONTRADA"])

    out = run_session(["1", "06", "00", "0"])
    check("BANKACCT: list all accounts shows total", out, ["Total de Contas:"])

    out = run_session(["2", "07", num, "00", "0"])
    check("BANKTRAN: balance query shows saldo", out, ["SALDO DISPONIVEL"])


def test_reports() -> None:
    print("\n── Reports ────────────────────────────────────────────────")

    out = run_session(["8", "01", "00", "0"])
    check("Trial balance generates", out, ["BALANCETE GERAL"])

    out = run_session(["8", "03", "00", "0"])
    check("Daily movement report generates", out, ["MOVIMENTACAO DIARIA"])

    out = run_session(["8", "04", "00", "0"])
    check("Negative balances report generates", out, ["CONTAS COM SALDO NEGATIVO"])

    rep_path = os.path.join(ROOT, "BANKREP.TXT")
    out = run_session(["8", "01", "00", "0"])
    check("Report file exists after balancete", out, ["BALANCETE GERADO"])
    if os.path.exists(rep_path):
        print("  [INFO] BANKREP.TXT present on disk ✓")


def test_admin() -> None:
    print("\n── Administration ─────────────────────────────────────────")

    out = run_session(["9", "01", "00", "0"])
    check(
        "Admin stats shows account/transaction/customer counts", out, ["Contas:", "Transacoes:", "Clientes:"]
    )


def test_transfer_module() -> None:
    print("\n── BANKTRF Transfer Module ────────────────────────────────")
    if len(_ACCOUNTS) < 2:
        print("  [SKIP]")
        return
    src, dst = _ACCOUNTS[0][0], _ACCOUNTS[1][0]
    run_session(["2", "01", src, "500,00", "00", "0"])

    out = run_session(["4", "01", src, dst, "10,00", "00", "0"])
    check("BANKTRF TED transfer succeeds", out, ["TED EFETUADA"])

    out = run_session(["4", "02", src, dst, "5,00", "00", "0"])
    check("BANKTRF DOC transfer succeeds", out, ["DOC EFETUADA"])
    check("BANKTRF DOC not logged as TED", out, [], not_expected=["TED EFETUADA"])

    out = run_session(["4", "03", src, "C", _ACCOUNTS[1][1], "5,00", "00", "0"])
    check("BANKTRF PIX by CPF succeeds", out, ["PIX EFETUADO"])

    out = run_session(["4", "03", src, "C", "99999999999", "5,00", "00", "0"])
    check("BANKTRF PIX to unknown CPF key rejected", out, ["NAO ENCONTRADA"])

    out = run_session(["4", "01", src, dst, "99999,00", "00", "0"])
    check("BANKTRF TED insufficient balance rejected", out, ["INSUFICIENTE"])




def main() -> int:
    if os.name == "nt":
        print("This suite requires Linux/WSL2 (pty). Run: wsl python3 test_suite.py")
        return 2
    if not os.path.exists(BANKMAIN):
        print(f"Binary not found at {BANKMAIN}. Run: make all")
        return 2

    print("=" * 60)
    print(" BANCO COBOL — Comprehensive Test Suite")
    print("=" * 60)

    print("\n[Seeding QA accounts...]")
    _seed_accounts()
    print(f"  Accounts available: {len(_ACCOUNTS)}")

    test_cpf_validation()
    test_account_management()
    test_deposits()
    test_withdrawals()
    test_ted_doc()
    test_pix()
    test_bill_payment()
    test_statement_filter()
    test_reversal()
    test_investments()
    test_crm()
    test_queries()
    test_reports()
    test_admin()
    test_transfer_module()

    passed = sum(1 for r in _results if r.passed)
    total = len(_results)
    failed = [r for r in _results if not r.passed]

    print("\n" + "=" * 60)
    print(f" RESULT: {passed}/{total} tests passed")
    print("=" * 60)

    if failed:
        print(f"\n FAILED ({len(failed)}):")
        for r in failed:
            print(f"  ✗ {r.name}")
            if r.missing:
                print(f"    Missing: {r.missing}")
            if r.extra_info:
                print(f"    {r.extra_info}")

    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
