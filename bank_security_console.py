"""Console seguro chamado pelo BANKMAIN/BANKAUTH.

No primeiro uso cria um administrador. Depois exige autenticação Argon2id e,
quando habilitado, TOTP. A senha usa getpass em terminal real e entrada comum
quando executada pela GUI com pipes.
"""

from __future__ import annotations

import getpass
import json
import os
import sqlite3
import sys
from pathlib import Path

from bank_core import AuthenticationError, AuthorizationError, BankingCore


DATABASE = Path(os.environ.get("BANK_CORE_DATABASE", "BANKCORE.db"))
SESSION_FILE = Path(os.environ.get("BANK_SESSION_FILE", "BANKSESSION.TMP"))


def secret(prompt: str) -> str:
    if sys.stdin.isatty():
        return getpass.getpass(prompt)
    return input(prompt)


def bootstrap(core: BankingCore) -> None:
    with core.database.connect() as con:
        count = con.execute("SELECT COUNT(*) FROM users").fetchone()[0]
    if count:
        return
    print("=== PRIMEIRO ACESSO: CRIAR ADMINISTRADOR ===")
    username = input("Usuário administrador: ").strip()
    password = secret("Senha forte: ")
    confirmation = secret("Confirme a senha: ")
    if password != confirmation:
        raise AuthenticationError("PASSWORD_MISMATCH", "Senhas não conferem")
    core.security.create_user(username, password, roles=["ADMIN"])
    print("Administrador criado. Faça o login.")


def login(core: BankingCore) -> dict[str, str]:
    username = input("Usuário: ").strip()
    password = secret("Senha: ")
    totp = input("TOTP (Enter se desativado): ").strip() or None
    session = core.security.authenticate(username, password, device="COBOL-CLI", totp_code=totp)
    SESSION_FILE.write_text(json.dumps({"username": username, **session}), encoding="utf-8")
    try:
        os.chmod(SESSION_FILE, 0o600)
    except OSError:
        pass
    print("AUTENTICADO COM SUCESSO")
    return session


def authenticated_session(core: BankingCore):
    if not SESSION_FILE.exists():
        raise AuthenticationError("SESSION_REQUIRED", "Sessão não encontrada")
    payload = json.loads(SESSION_FILE.read_text(encoding="utf-8"))
    session = core.security.require_session(payload["token"])
    return payload, session


def security_menu(core: BankingCore) -> int:
    payload, session = authenticated_session(core)
    user_id = session["user_id"]
    while True:
        print("========================================")
        print(" AUTENTICACAO E SEGURANCA")
        print("========================================")
        print(" 01. Login (CPF + Senha)")
        print(" 02. Alterar Senha")
        print(" 03. Verificacao em Dois Fatores (2FA)")
        print(" 04. Recuperar Acesso")
        print(" 05. Minha Pontuacao e Badges")
        print(" 06. Listar Sessoes")
        print(" 07. Revogar Todas as Sessoes")
        print(" 00. Voltar")
        option = input().strip()
        if option == "00":
            return 0
        if option == "01":
            print(f"SESSAO AUTENTICADA: {payload['username']}")
        elif option == "02":
            current = secret("Senha atual: ")
            new = secret("Nova senha: ")
            confirmation = secret("Confirme: ")
            if new != confirmation:
                print("SENHAS NAO CONFEREM")
                continue
            core.security.change_password(user_id, current, new)
            SESSION_FILE.unlink(missing_ok=True)
            print("SENHA ALTERADA; ENTRE NOVAMENTE")
            return 0
        elif option == "03":
            setup = core.security.enable_totp(user_id)
            print("SEGREDO TOTP:", setup["secret"])
            print("CODIGOS DE RECUPERACAO:")
            for code in setup["recovery_codes"]:
                print(code)
        elif option == "04":
            recipient = input("E-mail/telefone: ").strip()
            token = core.security.request_password_reset(payload["username"], recipient)
            print("SOLICITACAO REGISTRADA NO OUTBOX")
            if os.environ.get("BANK_DEVELOPMENT") == "1":
                print("TOKEN DE DESENVOLVIMENTO:", token)
        elif option == "05":
            with core.database.connect() as con:
                operations = con.execute(
                    "SELECT COUNT(*) FROM ledger_transactions WHERE created_by=?",
                    (user_id,),
                ).fetchone()[0]
            print("PONTOS:", operations * 10)
        elif option == "06":
            for item in core.security.list_sessions(user_id):
                print(json.dumps(item, ensure_ascii=False))
        elif option == "07":
            confirmation = input("Revogar todas? (S/N): ").strip().upper()
            if confirmation == "S":
                core.security.revoke_all_sessions(user_id)
                SESSION_FILE.unlink(missing_ok=True)
                print("SESSOES REVOGADAS")
                return 0
        else:
            print("OPCAO INVALIDA")


def logout() -> int:
    if not SESSION_FILE.exists():
        return 0
    core = BankingCore(DATABASE)
    payload = json.loads(SESSION_FILE.read_text(encoding="utf-8"))
    core.security.revoke_session(payload["session_id"])
    SESSION_FILE.unlink(missing_ok=True)
    return 0


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "login"
    try:
        if mode == "logout":
            return logout()
        core = BankingCore(DATABASE)
        if mode == "login":
            bootstrap(core)
            login(core)
            return 0
        if mode == "menu":
            return security_menu(core)
        raise ValueError(f"Modo desconhecido: {mode}")
    except (AuthenticationError, AuthorizationError, ValueError, sqlite3.Error) as exc:
        print("ACESSO NEGADO:", exc)
        return 5


if __name__ == "__main__":
    raise SystemExit(main())
