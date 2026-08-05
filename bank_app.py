"""Composition root do Banco COBOL.

Antes, cada chamador montava PIX, Open Finance, avançado e plataforma à mão —
e quem esquecesse de passar `security` ou `vault` recebia silenciosamente a
configuração insegura. Aqui a montagem é feita uma única vez, com as
dependências de segurança ligadas por padrão: o caminho fácil passa a ser o
caminho correto.

Este módulo é a única camada autorizada a conhecer todos os outros; nenhum
módulo de domínio importa daqui (a dependência aponta sempre para dentro).
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from bank_advanced import AdvancedBanking, KeyProvider
from bank_core import BankingCore
from bank_observability import LOGGER, METRICS
from bank_openfinance import OpenFinanceAPI, OpenFinanceService
from bank_pix import PixService
from bank_platform import BankPlatform


class BankApplication:
    """Sistema completo montado com segurança e cofre ativos."""

    def __init__(
        self,
        database_path: str | Path = "BANKCORE.db",
        *,
        master_key: bytes | None = None,
        key_provider: KeyProvider | None = None,
        with_security: bool = True,
    ):
        self.core = BankingCore(database_path, with_security=with_security)
        self.database = self.core.database
        self.ledger = self.core.ledger
        self.security = self.core.security

        self.advanced = AdvancedBanking(self.database, self.ledger, master_key, key_provider)
        self.vault = self.advanced.vault

        self.pix = PixService(
            self.database,
            self.ledger,
            self.core.modules,
            security=self.security,
            vault=self.vault,
        )
        self.open_finance = OpenFinanceService(
            self.database,
            self.ledger,
            security=self.security,
            vault=self.vault,
        )
        self.open_finance_api = OpenFinanceAPI(self.open_finance)
        self.platform = BankPlatform(self.database, self.ledger, self.security)

        LOGGER.info(
            "application.started",
            extra={"database": str(database_path), "security": bool(self.security)},
        )

    def health(self) -> dict[str, Any]:
        """Readiness real: integridade do arquivo, razão conciliado e auditoria."""
        integrity = self.database.integrity_check()
        reconciliation = self.ledger.reconcile()
        audit_ok = self.security.verify_audit_chain() if self.security else None
        healthy = integrity["ok"] and reconciliation["ok"] and audit_ok is not False
        METRICS.gauge("bank_health", 1 if healthy else 0)
        return {
            "status": "UP" if healthy else "DEGRADED",
            "integrity": integrity,
            "reconciliation": reconciliation,
            "audit_chain_valid": audit_ok,
        }

    def rotate_kek(self, new_provider: KeyProvider) -> dict[str, Any]:
        """Rotaciona a KEK do cofre (ADR-001, passo 4).

        Operação privilegiada e auditada: reembrulha DEKs e segredos sob a nova
        custódia sem reescrever nenhum dado cifrado. Depois dela a KEK anterior
        pode ser destruída no KMS.
        """
        report = self.advanced.vault.rotate_kek(new_provider)
        if self.security:
            self.security.audit(None, "KEK_ROTATION", "vault", "SUCCESS", report)
        return report

    def kek_status(self) -> dict[str, Any]:
        return self.advanced.vault.kek_status()

    def metrics(self) -> str:
        return METRICS.render_prometheus()
