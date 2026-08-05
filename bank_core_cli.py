"""CLI estruturada e ponte de integração COBOL -> núcleo transacional.

Todas as respostas são JSON e os códigos de saída são estáveis:
0 sucesso, 2 erro de domínio, 3 erro de autenticação/autorização, 99 erro fatal.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict, is_dataclass
from decimal import Decimal
from pathlib import Path
from typing import Any

from bank_core import (
    AuthenticationError,
    AuthorizationError,
    BankError,
    BankingCore,
    money_to_cents,
    utcnow,
)


def jsonify(value: Any) -> Any:
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, Path):
        return str(value)
    if is_dataclass(value):
        return asdict(value)
    if isinstance(value, dict):
        return {key: jsonify(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [jsonify(item) for item in value]
    return value


def emit(payload: Any) -> None:
    print(json.dumps(jsonify(payload), ensure_ascii=False, sort_keys=True))


def flatten_for_cobol(payload: Any, prefix: str = "") -> dict[str, str]:
    """Achata um payload JSON-like em pares CHAVE=VALOR de uma linha cada,
    consumíveis por COBOL sem parser JSON (via READ sequencial + comparação
    de prefixo)."""
    data = jsonify(payload)
    flat: dict[str, str] = {}

    def walk(value: Any, key: str) -> None:
        if isinstance(value, dict):
            for sub_key, sub_value in value.items():
                walk(sub_value, f"{key}_{sub_key}" if key else str(sub_key))
        elif isinstance(value, (list, tuple)):
            for index, item in enumerate(value):
                walk(item, f"{key}_{index}")
        elif value is None:
            flat[key.upper()] = ""
        elif isinstance(value, bool):
            flat[key.upper()] = "1" if value else "0"
        else:
            flat[key.upper()] = str(value)

    walk(data, prefix)
    return flat


def write_cobol_out(path: str, payload: Any) -> None:
    lines = [f"{key}={value}" for key, value in sorted(flatten_for_cobol(payload).items())]
    Path(path).write_text("\n".join(lines) + "\n", encoding="ascii", errors="replace")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(prog="bank-core")
    root.add_argument("--database", default="BANKCORE.db")
    root.add_argument(
        "--cobol-out",
        default=None,
        help="Caminho de arquivo texto CHAVE=VALOR para consumo por programas COBOL",
    )
    commands = root.add_subparsers(dest="command", required=True)

    commands.add_parser("init")

    user = commands.add_parser("create-user")
    user.add_argument("username")
    user.add_argument("password")
    user.add_argument("--cpf-cnpj")
    user.add_argument("--role", action="append", default=["CLIENT"])

    login = commands.add_parser("login")
    login.add_argument("username")
    login.add_argument("password")
    login.add_argument("--totp")
    login.add_argument("--device", default="CLI")

    account = commands.add_parser("create-account")
    account.add_argument("account")
    account.add_argument("owner")
    account.add_argument("--kind", default="CC")
    account.add_argument("--balance", default="0")
    account.add_argument("--overdraft", default="0")

    show = commands.add_parser("account")
    show.add_argument("account")

    transfer = commands.add_parser("transfer")
    transfer.add_argument("origin")
    transfer.add_argument("destination")
    transfer.add_argument("amount")
    transfer.add_argument("idempotency_key")
    transfer.add_argument("--kind", default="TRANSFER")
    transfer.add_argument("--description", default="Transferência")
    transfer.add_argument("--fee", default="0")
    transfer.add_argument("--actor")

    settle = commands.add_parser("settle")
    settle.add_argument("module")
    settle.add_argument("kind")
    settle.add_argument("account")
    settle.add_argument("amount")
    settle.add_argument("idempotency_key")
    settle.add_argument("--actor")
    settle.add_argument("--payload", default="{}")

    hold = commands.add_parser("hold")
    hold.add_argument("account")
    hold.add_argument("amount")
    hold.add_argument("reason")
    hold.add_argument("--expires-at")

    capture = commands.add_parser("capture")
    capture.add_argument("hold_id")
    capture.add_argument("idempotency_key")
    capture.add_argument("--amount")

    release = commands.add_parser("release")
    release.add_argument("hold_id")

    reverse = commands.add_parser("reverse")
    reverse.add_argument("transaction_id")
    reverse.add_argument("idempotency_key")
    reverse.add_argument("--amount")
    reverse.add_argument("--actor")

    schedule = commands.add_parser("schedule")
    schedule.add_argument("kind")
    schedule.add_argument("payload")
    schedule.add_argument("next_run_at")
    schedule.add_argument("--recurrence", default="ONCE")
    schedule.add_argument("--end-at")

    jobs = commands.add_parser("run-jobs")
    jobs.add_argument("--at")

    commands.add_parser("reconcile")
    commands.add_parser("integrity")
    commands.add_parser("repair")
    commands.add_parser("deliver-notifications")

    backup = commands.add_parser("backup")
    backup.add_argument("destination")

    close = commands.add_parser("close")
    close.add_argument("period")
    close.add_argument("close_type", choices=["DAILY", "MONTHLY"])
    close.add_argument("actor")

    migrate = commands.add_parser("migrate-isam-dump")
    migrate.add_argument("dump_path")
    return root


def _historical_transaction_already_imported(core: "BankingCore", legacy_id: str) -> bool:
    with core.database.connect() as con:
        row = con.execute(
            "SELECT 1 FROM module_events WHERE event_id = ?",
            (f"HIST-{legacy_id}",),
        ).fetchone()
    return row is not None


def _import_historical_transaction(
    core: "BankingCore",
    legacy_id: str,
    origin: str,
    destination: str,
    kind: str,
    amount: str,
    status: str,
) -> None:
    """Registra uma transacao legada do .DAT como evento histórico
    auditável em module_events, SEM aplicar delta de saldo — o saldo
    já está correto a partir do snapshot de conta migrado por
    migrate-isam-dump. Reaplicar o valor duplicaria o efeito."""
    value = money_to_cents(amount)
    payload = {
        "legacy_source": "BANKTRAN.DAT",
        "legacy_id": legacy_id,
        "origin_account": origin,
        "destination_account": destination,
        "legacy_status": status,
        "note": "importado sem afetar saldo",
    }
    with core.database.connect() as con:
        con.execute(
            "INSERT INTO module_events VALUES(?,?,?,?,?,?,?,?,?)",
            (
                f"HIST-{legacy_id}",
                "MIGRATION",
                kind.strip(),
                origin or None,
                value,
                None,
                json.dumps(payload, sort_keys=True),
                "HISTORICAL_IMPORT",
                utcnow(),
            ),
        )


def migrate_isam_dump(core: "BankingCore", dump_path: str) -> dict[str, Any]:
    """Importa o dump de BANKACCT.DAT/BANKTRAN.DAT gerado por
    BANKEXPORT.cob para o razao central, tornando o SQLite a fonte de
    verdade. Idempotente: contas ja existentes são ignoradas (chave =
    número da conta) e transações já importadas são identificadas por
    'HIST-<legacy_id>' em module_events. Transações históricas NÃO
    alteram saldo (já refletido no snapshot de conta) — são apenas
    registradas como trilha auditável."""
    imported = 0
    skipped = 0
    trans_imported = 0
    trans_skipped = 0
    errors: list[str] = []
    for line in Path(dump_path).read_text(encoding="ascii", errors="replace").splitlines():
        fields = line.split("|")
        if not fields:
            continue
        if fields[0] == "CONTA":
            _, account_number, owner_cpf, kind, status, balance = fields[:6]
            try:
                core.ledger.account(account_number)
                skipped += 1
                continue
            except BankError:
                pass
            try:
                core.ledger.create_account(
                    account_number, owner_cpf.strip(), kind.strip(), balance.strip(), 0
                )
                imported += 1
            except BankError as exc:
                errors.append(f"{account_number}: {exc}")
        elif fields[0] == "TRANS":
            _, legacy_id, origin, destination, kind, amount, status = fields[:7]
            if _historical_transaction_already_imported(core, legacy_id):
                trans_skipped += 1
                continue
            try:
                _import_historical_transaction(core, legacy_id, origin, destination, kind, amount, status)
                trans_imported += 1
            except Exception as exc:
                errors.append(f"trans {legacy_id}: {exc}")
    return {
        "ok": True,
        "imported": imported,
        "skipped": skipped,
        "transactions_imported": trans_imported,
        "transactions_skipped": trans_skipped,
        "errors": errors,
    }


def execute(args: argparse.Namespace) -> Any:
    core = BankingCore(args.database)
    command = args.command
    if command == "init":
        return {"ok": True, **core.database.integrity_check()}
    if command == "create-user":
        user_id = core.security.create_user(
            args.username, args.password, cpf_cnpj=args.cpf_cnpj, roles=args.role
        )
        return {"ok": True, "user_id": user_id}
    if command == "login":
        return {
            "ok": True,
            **core.security.authenticate(
                args.username, args.password, device=args.device, totp_code=args.totp
            ),
        }
    if command == "create-account":
        core.ledger.create_account(args.account, args.owner, args.kind, args.balance, args.overdraft)
        return {"ok": True, "account": args.account}
    if command == "account":
        return {"ok": True, **core.ledger.account(args.account)}
    if command == "transfer":
        transaction_id = core.ledger.transfer(
            args.origin,
            args.destination,
            args.amount,
            args.idempotency_key,
            kind=args.kind,
            description=args.description,
            created_by=args.actor,
            fee=args.fee,
        )
        return {"ok": True, "transaction_id": transaction_id}
    if command == "settle":
        transaction_id = core.modules.settle(
            args.module,
            args.kind,
            args.account,
            args.amount,
            args.idempotency_key,
            actor_id=args.actor,
            payload=json.loads(args.payload),
        )
        return {"ok": True, "transaction_id": transaction_id}
    if command == "hold":
        return {
            "ok": True,
            "hold_id": core.ledger.create_hold(args.account, args.amount, args.reason, args.expires_at),
        }
    if command == "capture":
        return {
            "ok": True,
            "transaction_id": core.ledger.capture_hold(args.hold_id, args.idempotency_key, args.amount),
        }
    if command == "release":
        core.ledger.release_hold(args.hold_id)
        return {"ok": True}
    if command == "reverse":
        return {
            "ok": True,
            "transaction_id": core.ledger.reverse(
                args.transaction_id,
                args.idempotency_key,
                args.amount,
                created_by=args.actor,
            ),
        }
    if command == "schedule":
        return {
            "ok": True,
            "job_id": core.modules.schedule(
                args.kind,
                json.loads(args.payload),
                args.next_run_at,
                recurrence=args.recurrence,
                end_at=args.end_at,
            ),
        }
    if command == "run-jobs":
        return {"ok": True, **core.modules.run_due(args.at)}
    if command == "reconcile":
        return core.ledger.reconcile()
    if command == "integrity":
        return core.database.integrity_check()
    if command == "repair":
        return core.database.repair()
    if command == "deliver-notifications":
        return {"ok": True, **core.outbox.deliver_pending()}
    if command == "backup":
        return {"ok": True, "path": core.database.backup(args.destination)}
    if command == "close":
        core.ledger.close_period(args.period, args.close_type, args.actor)
        return {"ok": True}
    if command == "migrate-isam-dump":
        return migrate_isam_dump(core, args.dump_path)
    raise BankError("UNKNOWN_COMMAND", command)


def main() -> int:
    args = parser().parse_args()
    try:
        result = execute(args)
        emit(result)
        if args.cobol_out:
            write_cobol_out(args.cobol_out, result)
        return 0
    except (AuthenticationError, AuthorizationError) as exc:
        payload = {"ok": False, "code": exc.code, "error": str(exc)}
        emit(payload)
        if args.cobol_out:
            write_cobol_out(args.cobol_out, payload)
        return 3
    except BankError as exc:
        payload = {"ok": False, "code": exc.code, "error": str(exc)}
        emit(payload)
        if args.cobol_out:
            write_cobol_out(args.cobol_out, payload)
        return 2
    except Exception as exc:
        payload = {"ok": False, "code": "FATAL", "error": str(exc)}
        emit(payload)
        if args.cobol_out:
            write_cobol_out(args.cobol_out, payload)
        return 99


if __name__ == "__main__":
    sys.exit(main())
