#!/usr/bin/env python3
"""Finance-only acceptance regression for the COBOL banking system."""

import sys

from acceptance_regression import (
    discover_active_accounts,
    make_valid_barcode,
    run_session,
)


def main() -> int:
    accounts = discover_active_accounts()
    if len(accounts) < 2:
        print("Need at least 2 active accounts before running finance regression.")
        return 1

    origem = accounts[0][0]
    destino = accounts[1][0]
    destino_email = accounts[1][2]
    destino_cpf = accounts[1][1]

    pix_tipo = "E" if "@" in destino_email else "C"
    pix_chave = destino_email if pix_tipo == "E" else destino_cpf
    barcode = make_valid_barcode()

    cases = [
        ("Deposito", ["2", "01", origem, "700,00", "00", "0"], "DEPOSITO REALIZADO"),
        ("TED", ["4", "01", origem, destino, "10,00", "00", "0"], "TED EFETUADA"),
        ("DOC", ["4", "02", origem, destino, "10,00", "00", "0"], "DOC EFETUADA"),
        ("PIX", ["4", "03", origem, pix_tipo, pix_chave, "5,00", "00", "0"], "PIX EFETUADO"),
        ("Pagamento Boleto", ["5", "01", origem, barcode, "3,00", "00", "0"], "BOLETO PAGO"),
    ]

    passed = 0
    for name, inputs, token in cases:
        output = run_session(inputs)
        ok = token in output
        print(f"[{ 'PASS' if ok else 'FAIL' }] {name}")
        if not ok:
            print(f"  expected token: {token}")
            return 1
        passed += 1

    print(f"\nResult: {passed}/{len(cases)} checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
