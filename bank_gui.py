#!/usr/bin/env python3
"""GUI frontend for the COBOL banking system."""

from __future__ import annotations

import queue
import re
import subprocess
import threading
import time
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox
from tkinter.scrolledtext import ScrolledText

from bank_export import (
    AVAILABLE_FORMATS,
    export_formats,
    parse_extrato_lines,
)


def windows_path_to_wsl(path: Path) -> str:
    resolved = str(path.resolve())
    if len(resolved) >= 2 and resolved[1] == ":":
        drive = resolved[0].lower()
        tail = resolved[2:].replace("\\", "/")
        return f"/mnt/{drive}{tail}"
    return resolved


class BankGuiApp:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("Banco COBOL - Interface Grafica")
        self.root.geometry("1060x760")

        self.process: subprocess.Popen[str] | None = None
        self.output_queue: queue.Queue[str] = queue.Queue()
        self._mask_updating = False

        self._build_ui()
        self._bind_masks()
        self._schedule_queue_drain()

        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

    def _build_ui(self) -> None:
        top = tk.Frame(self.root, padx=12, pady=10)
        top.pack(fill=tk.X)

        self.status_var = tk.StringVar(value="Status: parado")
        tk.Label(top, textvariable=self.status_var, anchor="w").pack(side=tk.LEFT)

        controls = tk.Frame(top)
        controls.pack(side=tk.RIGHT)
        tk.Button(controls, text="Iniciar", width=10, command=self.start_session).pack(side=tk.LEFT, padx=4)
        tk.Button(controls, text="Parar", width=10, command=self.stop_session).pack(side=tk.LEFT, padx=4)
        tk.Button(controls, text="Limpar", width=10, command=self.clear_output).pack(side=tk.LEFT, padx=4)

        app_panel = tk.LabelFrame(self.root, text="Painel de Acoes", padx=10, pady=8)
        app_panel.pack(fill=tk.X, padx=12, pady=(0, 8))

        nav = tk.Frame(app_panel)
        nav.pack(fill=tk.X, pady=(0, 6))
        for label, cmd in [
            ("Menu Principal", "0"),
            ("Gestao de Contas", "1"),
            ("Transacoes", "2"),
            ("Investimentos", "6"),
            ("Relatorios", "8"),
            ("Emprestimos", "A"),
            ("Cartoes", "B"),
            ("Agendamentos", "C"),
        ]:
            tk.Button(nav, text=label, width=16, command=lambda c=cmd: self.send_input(c)).pack(side=tk.LEFT, padx=3)

        contas = tk.LabelFrame(app_panel, text="Atalhos de Contas", padx=8, pady=6)
        contas.pack(fill=tk.X)
        conta_actions = [
            ("Abrir Conta", "01"),
            ("Consultar Conta", "02"),
            ("Atualizar Dados", "03"),
            ("Bloq/Desbloq", "04"),
            ("Encerrar Conta", "05"),
            ("Listar Contas", "06"),
            ("Buscar por CPF", "07"),
            ("Aplicar Tarifa", "08"),
            ("Relatorio", "09"),
            ("Voltar", "00"),
        ]
        for idx, (label, code) in enumerate(conta_actions):
            tk.Button(contas, text=label, width=14, command=lambda v=code: self.send_input(v)).grid(
                row=idx // 5, column=idx % 5, padx=3, pady=3, sticky="w"
            )

        input_box = tk.LabelFrame(self.root, text="Entrada", padx=10, pady=8)
        input_box.pack(fill=tk.X, padx=12, pady=(0, 8))
        self.input_var = tk.StringVar()
        entry = tk.Entry(input_box, textvariable=self.input_var)
        entry.pack(side=tk.LEFT, fill=tk.X, expand=True)
        entry.bind("<Return>", lambda _e: self.send_input(self.input_var.get()))
        tk.Button(input_box, text="Enviar", width=10, command=lambda: self.send_input(self.input_var.get())).pack(
            side=tk.LEFT, padx=(8, 0)
        )

        guided = tk.LabelFrame(self.root, text="Fluxo Guiado", padx=10, pady=8)
        guided.pack(fill=tk.X, padx=12, pady=(0, 8))
        self._build_open_account_form(guided)
        self._build_consult_account_form(guided)
        self._build_deposit_form(guided)
        self._build_withdraw_form(guided)
        self._build_transfer_form(guided)
        self._build_payment_form(guided)
        self._build_investment_form(guided)
        self._build_report_form(guided)
        self._build_export_form(guided)
        self._build_loan_form(guided)
        self._build_card_form(guided)
        self._build_schedule_form(guided)

        output_box = tk.LabelFrame(self.root, text="Saida do Sistema", padx=10, pady=8)
        output_box.pack(fill=tk.BOTH, expand=True, padx=12, pady=(0, 12))
        self.output = ScrolledText(output_box, wrap=tk.WORD, height=22, state=tk.DISABLED)
        self.output.pack(fill=tk.BOTH, expand=True)

    def _build_open_account_form(self, parent: tk.Widget) -> None:
        frame = tk.LabelFrame(parent, text="Abrir Conta", padx=8, pady=6)
        frame.pack(fill=tk.X, pady=(0, 6))

        self.open_nome_var = tk.StringVar()
        self.open_cpf_var = tk.StringVar()
        self.open_tipo_var = tk.StringVar(value="CC")
        self.open_agencia_var = tk.StringVar()
        self.open_email_var = tk.StringVar()
        self.open_telefone_var = tk.StringVar()
        self.open_back_to_main_var = tk.BooleanVar(value=True)

        tk.Label(frame, text="Nome").grid(row=0, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.open_nome_var, width=30).grid(row=0, column=1, padx=4)
        tk.Label(frame, text="CPF").grid(row=0, column=2, sticky="w")
        tk.Entry(frame, textvariable=self.open_cpf_var, width=16).grid(row=0, column=3, padx=4)
        tk.Label(frame, text="Tipo").grid(row=0, column=4, sticky="w")
        tk.OptionMenu(frame, self.open_tipo_var, "CC", "CP", "CS", "CI").grid(row=0, column=5, padx=4, sticky="w")

        tk.Label(frame, text="Agencia").grid(row=1, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.open_agencia_var, width=10).grid(row=1, column=1, padx=4, sticky="w")
        tk.Label(frame, text="Email").grid(row=1, column=2, sticky="w")
        tk.Entry(frame, textvariable=self.open_email_var, width=28).grid(row=1, column=3, padx=4, columnspan=2, sticky="we")
        tk.Label(frame, text="Telefone").grid(row=1, column=5, sticky="w")
        tk.Entry(frame, textvariable=self.open_telefone_var, width=16).grid(row=1, column=6, padx=4, sticky="w")

        tk.Checkbutton(frame, text="Voltar ao menu principal apos abrir", variable=self.open_back_to_main_var).grid(
            row=2, column=0, columnspan=4, sticky="w", pady=(6, 0)
        )
        tk.Button(frame, text="Executar Abertura", width=18, command=self.open_account_flow).grid(
            row=2, column=5, columnspan=2, padx=4, pady=(6, 0), sticky="e"
        )

    def _build_consult_account_form(self, parent: tk.Widget) -> None:
        frame = tk.LabelFrame(parent, text="Consultar Conta", padx=8, pady=6)
        frame.pack(fill=tk.X)

        self.consult_num_var = tk.StringVar()
        self.consult_back_to_main_var = tk.BooleanVar(value=True)

        tk.Label(frame, text="Numero da Conta").grid(row=0, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.consult_num_var, width=20).grid(row=0, column=1, padx=4, sticky="w")
        tk.Checkbutton(frame, text="Voltar ao menu principal apos consultar", variable=self.consult_back_to_main_var).grid(
            row=0, column=2, padx=8, sticky="w"
        )
        tk.Button(frame, text="Executar Consulta", width=18, command=self.consult_account_flow).grid(
            row=0, column=3, padx=4, sticky="e"
        )

    def _build_deposit_form(self, parent: tk.Widget) -> None:
        frame = tk.LabelFrame(parent, text="Deposito", padx=8, pady=6)
        frame.pack(fill=tk.X, pady=(6, 0))

        self.dep_conta_var = tk.StringVar()
        self.dep_valor_var = tk.StringVar()
        self.dep_back_to_main_var = tk.BooleanVar(value=True)

        tk.Label(frame, text="Conta").grid(row=0, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.dep_conta_var, width=16).grid(row=0, column=1, padx=4, sticky="w")
        tk.Label(frame, text="Valor").grid(row=0, column=2, sticky="w")
        val_dep = tk.Frame(frame)
        val_dep.grid(row=0, column=3, padx=4, sticky="w")
        tk.Label(val_dep, text="R$").pack(side=tk.LEFT)
        tk.Entry(val_dep, textvariable=self.dep_valor_var, width=16).pack(side=tk.LEFT, padx=(3, 0))
        tk.Checkbutton(frame, text="Voltar ao menu principal apos operacao", variable=self.dep_back_to_main_var).grid(
            row=0, column=4, padx=8, sticky="w"
        )
        tk.Button(frame, text="Executar Deposito", width=18, command=self.deposit_flow).grid(
            row=0, column=5, padx=4, sticky="e"
        )

    def _build_withdraw_form(self, parent: tk.Widget) -> None:
        frame = tk.LabelFrame(parent, text="Saque", padx=8, pady=6)
        frame.pack(fill=tk.X, pady=(6, 0))

        self.saq_conta_var = tk.StringVar()
        self.saq_valor_var = tk.StringVar()
        self.saq_back_to_main_var = tk.BooleanVar(value=True)

        tk.Label(frame, text="Conta").grid(row=0, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.saq_conta_var, width=16).grid(row=0, column=1, padx=4, sticky="w")
        tk.Label(frame, text="Valor").grid(row=0, column=2, sticky="w")
        val_saq = tk.Frame(frame)
        val_saq.grid(row=0, column=3, padx=4, sticky="w")
        tk.Label(val_saq, text="R$").pack(side=tk.LEFT)
        tk.Entry(val_saq, textvariable=self.saq_valor_var, width=16).pack(side=tk.LEFT, padx=(3, 0))
        tk.Checkbutton(frame, text="Voltar ao menu principal apos operacao", variable=self.saq_back_to_main_var).grid(
            row=0, column=4, padx=8, sticky="w"
        )
        tk.Button(frame, text="Executar Saque", width=18, command=self.withdraw_flow).grid(
            row=0, column=5, padx=4, sticky="e"
        )

    def _build_transfer_form(self, parent: tk.Widget) -> None:
        frame = tk.LabelFrame(parent, text="Transferencias", padx=8, pady=6)
        frame.pack(fill=tk.X, pady=(6, 0))

        self.trf_tipo_var = tk.StringVar(value="TED")
        self.trf_origem_var = tk.StringVar()
        self.trf_destino_var = tk.StringVar()
        self.trf_pix_tipo_var = tk.StringVar(value="C")
        self.trf_pix_chave_var = tk.StringVar()
        self.trf_valor_var = tk.StringVar()
        self.trf_back_to_main_var = tk.BooleanVar(value=True)

        tk.Label(frame, text="Tipo").grid(row=0, column=0, sticky="w")
        tk.OptionMenu(frame, self.trf_tipo_var, "TED", "DOC", "PIX").grid(row=0, column=1, padx=4, sticky="w")
        tk.Label(frame, text="Conta Origem").grid(row=0, column=2, sticky="w")
        tk.Entry(frame, textvariable=self.trf_origem_var, width=14).grid(row=0, column=3, padx=4, sticky="w")
        tk.Label(frame, text="Conta Destino").grid(row=0, column=4, sticky="w")
        tk.Entry(frame, textvariable=self.trf_destino_var, width=14).grid(row=0, column=5, padx=4, sticky="w")

        tk.Label(frame, text="Valor").grid(row=0, column=6, sticky="w")
        val_trf = tk.Frame(frame)
        val_trf.grid(row=0, column=7, padx=4, sticky="w")
        tk.Label(val_trf, text="R$").pack(side=tk.LEFT)
        tk.Entry(val_trf, textvariable=self.trf_valor_var, width=12).pack(side=tk.LEFT, padx=(3, 0))

        tk.Label(frame, text="PIX Tipo").grid(row=1, column=0, sticky="w")
        tk.OptionMenu(frame, self.trf_pix_tipo_var, "C", "E", "T").grid(row=1, column=1, padx=4, sticky="w")
        tk.Label(frame, text="PIX Chave").grid(row=1, column=2, sticky="w")
        tk.Entry(frame, textvariable=self.trf_pix_chave_var, width=24).grid(row=1, column=3, columnspan=3, padx=4, sticky="we")

        tk.Checkbutton(frame, text="Voltar ao menu principal apos operacao", variable=self.trf_back_to_main_var).grid(
            row=1, column=6, columnspan=2, padx=8, sticky="w"
        )
        tk.Button(frame, text="Executar Transferencia", width=18, command=self.transfer_flow).grid(
            row=1, column=8, padx=6, sticky="e"
        )

    def _build_payment_form(self, parent: tk.Widget) -> None:
        frame = tk.LabelFrame(parent, text="Pagamentos", padx=8, pady=6)
        frame.pack(fill=tk.X, pady=(6, 0))

        self.pay_conta_var = tk.StringVar()
        self.pay_codigo_var = tk.StringVar()
        self.pay_valor_var = tk.StringVar()
        self.pay_back_to_main_var = tk.BooleanVar(value=True)

        tk.Label(frame, text="Conta Debito").grid(row=0, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.pay_conta_var, width=16).grid(row=0, column=1, padx=4, sticky="w")
        tk.Label(frame, text="Codigo barras").grid(row=0, column=2, sticky="w")
        tk.Entry(frame, textvariable=self.pay_codigo_var, width=30).grid(row=0, column=3, padx=4, sticky="w")
        tk.Label(frame, text="Valor").grid(row=0, column=4, sticky="w")
        val_pay = tk.Frame(frame)
        val_pay.grid(row=0, column=5, padx=4, sticky="w")
        tk.Label(val_pay, text="R$").pack(side=tk.LEFT)
        tk.Entry(val_pay, textvariable=self.pay_valor_var, width=16).pack(side=tk.LEFT, padx=(3, 0))

        tk.Checkbutton(frame, text="Voltar ao menu principal apos operacao", variable=self.pay_back_to_main_var).grid(
            row=1, column=0, columnspan=3, pady=(4, 0), sticky="w"
        )
        tk.Button(frame, text="Executar Pagamento", width=18, command=self.payment_flow).grid(
            row=1, column=5, padx=6, pady=(4, 0), sticky="e"
        )

    def _build_investment_form(self, parent: tk.Widget) -> None:
        frame = tk.LabelFrame(parent, text="Investimento CDB", padx=8, pady=6)
        frame.pack(fill=tk.X, pady=(6, 0))

        self.inv_valor_var = tk.StringVar()
        self.inv_prazo_var = tk.StringVar()
        self.inv_confirmar_var = tk.BooleanVar(value=True)
        self.inv_back_to_main_var = tk.BooleanVar(value=True)

        tk.Label(frame, text="Valor").grid(row=0, column=0, sticky="w")
        val_inv = tk.Frame(frame)
        val_inv.grid(row=0, column=1, padx=4, sticky="w")
        tk.Label(val_inv, text="R$").pack(side=tk.LEFT)
        tk.Entry(val_inv, textvariable=self.inv_valor_var, width=16).pack(side=tk.LEFT, padx=(3, 0))
        tk.Label(frame, text="Prazo (dias)").grid(row=0, column=2, sticky="w")
        tk.Entry(frame, textvariable=self.inv_prazo_var, width=12).grid(row=0, column=3, padx=4, sticky="w")

        tk.Checkbutton(frame, text="Confirmar aplicacao automaticamente", variable=self.inv_confirmar_var).grid(
            row=0, column=4, padx=8, sticky="w"
        )
        tk.Checkbutton(frame, text="Voltar ao menu principal apos operacao", variable=self.inv_back_to_main_var).grid(
            row=1, column=0, columnspan=4, pady=(4, 0), sticky="w"
        )
        tk.Button(frame, text="Executar CDB", width=18, command=self.investment_cdb_flow).grid(
            row=1, column=4, padx=4, pady=(4, 0), sticky="e"
        )

    def _build_report_form(self, parent: tk.Widget) -> None:
        frame = tk.LabelFrame(parent, text="Relatorios", padx=8, pady=6)
        frame.pack(fill=tk.X, pady=(6, 0))

        self.rep_tipo_var = tk.StringVar(value="01")
        self.rep_back_to_main_var = tk.BooleanVar(value=True)

        tk.Label(frame, text="Tipo").grid(row=0, column=0, sticky="w")
        tk.OptionMenu(frame, self.rep_tipo_var, "01", "02", "03", "04", "05", "06", "07", "08").grid(
            row=0, column=1, padx=4, sticky="w"
        )
        tk.Label(frame, text="01=Balancete, 02=Resumo, 03=Mov.Diaria, 04=Negativos").grid(
            row=0, column=2, padx=6, sticky="w"
        )
        tk.Checkbutton(frame, text="Voltar ao menu principal apos relatorio", variable=self.rep_back_to_main_var).grid(
            row=0, column=3, padx=8, sticky="w"
        )
        tk.Button(frame, text="Executar Relatorio", width=18, command=self.report_flow).grid(
            row=0, column=4, padx=4, sticky="e"
        )

    def _build_export_form(self, parent: tk.Widget) -> None:
        frame = tk.LabelFrame(parent, text="Exportar Extrato", padx=8, pady=6)
        frame.pack(fill=tk.X, pady=(6, 0))

        self.exp_dir_var = tk.StringVar(value=str(Path.home() / "exports"))
        self.exp_stem_var = tk.StringVar(value="extrato")
        self._exp_fmt_vars: dict[str, tk.BooleanVar] = {
            fmt: tk.BooleanVar(value=fmt in ("csv", "html", "txt"))
            for fmt in AVAILABLE_FORMATS
        }

        tk.Label(frame, text="Pasta de saída").grid(row=0, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.exp_dir_var, width=36).grid(row=0, column=1, padx=4, sticky="we", columnspan=3)
        tk.Button(frame, text="…", width=3,
                  command=lambda: self.exp_dir_var.set(
                      filedialog.askdirectory(initialdir=self.exp_dir_var.get()) or self.exp_dir_var.get()
                  )).grid(row=0, column=4, padx=2)

        tk.Label(frame, text="Nome base").grid(row=0, column=5, sticky="w", padx=(10, 0))
        tk.Entry(frame, textvariable=self.exp_stem_var, width=18).grid(row=0, column=6, padx=4, sticky="w")

        fmt_frame = tk.Frame(frame)
        fmt_frame.grid(row=1, column=0, columnspan=7, sticky="w", pady=(6, 2))
        tk.Label(fmt_frame, text="Formatos:").pack(side=tk.LEFT, padx=(0, 6))
        for fmt, var in self._exp_fmt_vars.items():
            tk.Checkbutton(fmt_frame, text=fmt.upper(), variable=var).pack(side=tk.LEFT, padx=3)

        btn_frame = tk.Frame(frame)
        btn_frame.grid(row=2, column=0, columnspan=7, sticky="e", pady=(4, 0))
        tk.Button(btn_frame, text="Selecionar Tudo", width=14,
                  command=lambda: [v.set(True) for v in self._exp_fmt_vars.values()]).pack(side=tk.LEFT, padx=3)
        tk.Button(btn_frame, text="Limpar Seleção", width=14,
                  command=lambda: [v.set(False) for v in self._exp_fmt_vars.values()]).pack(side=tk.LEFT, padx=3)
        tk.Button(btn_frame, text="Exportar Saída Atual", width=20,
                  bg="#1a3c6e", fg="white", command=self.export_flow).pack(side=tk.LEFT, padx=6)

    def _build_loan_form(self, parent: tk.Widget) -> None:
        frame = tk.LabelFrame(parent, text="Emprestimos", padx=8, pady=6)
        frame.pack(fill=tk.X, pady=(6, 0))

        self.loan_op_var = tk.StringVar(value="01")
        self.loan_conta_var = tk.StringVar()
        self.loan_tipo_var = tk.StringVar(value="PES")
        self.loan_valor_var = tk.StringVar()
        self.loan_parcelas_var = tk.StringVar()
        self.loan_id_var = tk.StringVar()
        self.loan_back_var = tk.BooleanVar(value=True)

        tk.Label(frame, text="Operacao").grid(row=0, column=0, sticky="w")
        tk.OptionMenu(frame, self.loan_op_var, "01", "02", "03", "04", "05", "06").grid(
            row=0, column=1, padx=4, sticky="w"
        )
        tk.Label(frame, text="01=Solicitar 02=Consultar 03=Pagar 04=Simular 05=Listar 06=Quitar").grid(
            row=0, column=2, padx=6, sticky="w", columnspan=4
        )
        tk.Label(frame, text="Conta").grid(row=1, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.loan_conta_var, width=14).grid(row=1, column=1, padx=4, sticky="w")
        tk.Label(frame, text="Tipo").grid(row=1, column=2, sticky="w")
        tk.OptionMenu(frame, self.loan_tipo_var, "PES", "CON", "IMO", "VEI").grid(row=1, column=3, padx=4, sticky="w")
        tk.Label(frame, text="Valor").grid(row=1, column=4, sticky="w")
        tk.Entry(frame, textvariable=self.loan_valor_var, width=14).grid(row=1, column=5, padx=4, sticky="w")
        tk.Label(frame, text="Parcelas").grid(row=1, column=6, sticky="w")
        tk.Entry(frame, textvariable=self.loan_parcelas_var, width=8).grid(row=1, column=7, padx=4, sticky="w")
        tk.Label(frame, text="ID Empr").grid(row=2, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.loan_id_var, width=14).grid(row=2, column=1, padx=4, sticky="w")
        tk.Checkbutton(frame, text="Voltar ao menu principal", variable=self.loan_back_var).grid(
            row=2, column=2, columnspan=3, sticky="w"
        )
        tk.Button(frame, text="Executar", width=14, command=self.loan_flow).grid(
            row=2, column=5, columnspan=2, padx=4, sticky="e"
        )

    def _build_card_form(self, parent: tk.Widget) -> None:
        frame = tk.LabelFrame(parent, text="Cartoes Bancarios", padx=8, pady=6)
        frame.pack(fill=tk.X, pady=(6, 0))

        self.card_op_var = tk.StringVar(value="01")
        self.card_conta_var = tk.StringVar()
        self.card_tipo_var = tk.StringVar(value="D")
        self.card_limite_var = tk.StringVar()
        self.card_num_var = tk.StringVar()
        self.card_valor_var = tk.StringVar()
        self.card_back_var = tk.BooleanVar(value=True)

        tk.Label(frame, text="Operacao").grid(row=0, column=0, sticky="w")
        tk.OptionMenu(frame, self.card_op_var, "01", "02", "03", "04", "05", "06", "07", "08").grid(
            row=0, column=1, padx=4, sticky="w"
        )
        tk.Label(frame, text="01=Emitir 02=Consultar 03=Bloquear 04=Desbloquear"
                 " 05=Limite 06=Fatura 07=Pagar 08=Listar").grid(
            row=0, column=2, padx=6, sticky="w", columnspan=5
        )
        tk.Label(frame, text="Conta").grid(row=1, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.card_conta_var, width=14).grid(row=1, column=1, padx=4, sticky="w")
        tk.Label(frame, text="Tipo").grid(row=1, column=2, sticky="w")
        tk.OptionMenu(frame, self.card_tipo_var, "D", "C").grid(row=1, column=3, padx=4, sticky="w")
        tk.Label(frame, text="Limite").grid(row=1, column=4, sticky="w")
        tk.Entry(frame, textvariable=self.card_limite_var, width=14).grid(row=1, column=5, padx=4, sticky="w")
        tk.Label(frame, text="Num Cartao").grid(row=2, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.card_num_var, width=20).grid(row=2, column=1, padx=4, sticky="w")
        tk.Label(frame, text="Valor Pgto").grid(row=2, column=2, sticky="w")
        tk.Entry(frame, textvariable=self.card_valor_var, width=14).grid(row=2, column=3, padx=4, sticky="w")
        tk.Checkbutton(frame, text="Voltar ao menu principal", variable=self.card_back_var).grid(
            row=2, column=4, columnspan=2, sticky="w"
        )
        tk.Button(frame, text="Executar", width=14, command=self.card_flow).grid(
            row=2, column=6, padx=4, sticky="e"
        )

    def _build_schedule_form(self, parent: tk.Widget) -> None:
        frame = tk.LabelFrame(parent, text="Agendamentos", padx=8, pady=6)
        frame.pack(fill=tk.X, pady=(6, 0))

        self.schd_op_var = tk.StringVar(value="01")
        self.schd_conta_var = tk.StringVar()
        self.schd_tipo_var = tk.StringVar(value="TED")
        self.schd_dest_var = tk.StringVar()
        self.schd_valor_var = tk.StringVar()
        self.schd_data_var = tk.StringVar()
        self.schd_rec_var = tk.StringVar(value="U")
        self.schd_id_var = tk.StringVar()
        self.schd_back_var = tk.BooleanVar(value=True)

        tk.Label(frame, text="Operacao").grid(row=0, column=0, sticky="w")
        tk.OptionMenu(frame, self.schd_op_var, "01", "02", "03", "04", "05").grid(
            row=0, column=1, padx=4, sticky="w"
        )
        tk.Label(frame, text="01=Agendar Trf 02=Agendar Pag 03=Listar 04=Cancelar 05=Processar").grid(
            row=0, column=2, padx=6, sticky="w", columnspan=5
        )
        tk.Label(frame, text="Conta").grid(row=1, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.schd_conta_var, width=14).grid(row=1, column=1, padx=4, sticky="w")
        tk.Label(frame, text="Tipo").grid(row=1, column=2, sticky="w")
        tk.OptionMenu(frame, self.schd_tipo_var, "TED", "DOC", "PIX", "BOL").grid(row=1, column=3, padx=4, sticky="w")
        tk.Label(frame, text="Destino").grid(row=1, column=4, sticky="w")
        tk.Entry(frame, textvariable=self.schd_dest_var, width=14).grid(row=1, column=5, padx=4, sticky="w")
        tk.Label(frame, text="Valor").grid(row=1, column=6, sticky="w")
        tk.Entry(frame, textvariable=self.schd_valor_var, width=14).grid(row=1, column=7, padx=4, sticky="w")
        tk.Label(frame, text="Data(AAAAMMDD)").grid(row=2, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.schd_data_var, width=12).grid(row=2, column=1, padx=4, sticky="w")
        tk.Label(frame, text="Recor").grid(row=2, column=2, sticky="w")
        tk.OptionMenu(frame, self.schd_rec_var, "U", "M", "S").grid(row=2, column=3, padx=4, sticky="w")
        tk.Label(frame, text="ID Agend").grid(row=2, column=4, sticky="w")
        tk.Entry(frame, textvariable=self.schd_id_var, width=12).grid(row=2, column=5, padx=4, sticky="w")
        tk.Checkbutton(frame, text="Voltar ao menu principal", variable=self.schd_back_var).grid(
            row=2, column=6, sticky="w"
        )
        tk.Button(frame, text="Executar", width=14, command=self.schedule_flow).grid(
            row=2, column=7, padx=4, sticky="e"
        )

    def _bind_masks(self) -> None:
        self.open_cpf_var.trace_add("write", lambda *_: self._mask_cpf_var())
        self.open_telefone_var.trace_add("write", lambda *_: self._mask_phone_var())
        self.dep_valor_var.trace_add("write", lambda *_: self._mask_money_var(self.dep_valor_var))
        self.saq_valor_var.trace_add("write", lambda *_: self._mask_money_var(self.saq_valor_var))
        self.trf_valor_var.trace_add("write", lambda *_: self._mask_money_var(self.trf_valor_var))
        self.pay_valor_var.trace_add("write", lambda *_: self._mask_money_var(self.pay_valor_var))
        self.inv_valor_var.trace_add("write", lambda *_: self._mask_money_var(self.inv_valor_var))

    def _set_var_safely(self, var: tk.StringVar, value: str) -> None:
        if self._mask_updating:
            return
        self._mask_updating = True
        var.set(value)
        self._mask_updating = False

    def _mask_cpf_var(self) -> None:
        if self._mask_updating:
            return
        digits = self._digits_only(self.open_cpf_var.get())[:11]
        if len(digits) <= 3:
            masked = digits
        elif len(digits) <= 6:
            masked = f"{digits[:3]}.{digits[3:]}"
        elif len(digits) <= 9:
            masked = f"{digits[:3]}.{digits[3:6]}.{digits[6:]}"
        else:
            masked = f"{digits[:3]}.{digits[3:6]}.{digits[6:9]}-{digits[9:11]}"
        if masked != self.open_cpf_var.get():
            self._set_var_safely(self.open_cpf_var, masked)

    def _mask_phone_var(self) -> None:
        if self._mask_updating:
            return
        digits = self._digits_only(self.open_telefone_var.get())[:15]
        if len(digits) <= 2:
            masked = digits
        elif len(digits) <= 6:
            masked = f"({digits[:2]}) {digits[2:]}"
        elif len(digits) == 10:
            masked = f"({digits[:2]}) {digits[2:6]}-{digits[6:10]}"
        elif len(digits) >= 11:
            masked = f"({digits[:2]}) {digits[2:7]}-{digits[7:11]}"
        else:
            masked = f"({digits[:2]}) {digits[2:]}"
        if masked != self.open_telefone_var.get():
            self._set_var_safely(self.open_telefone_var, masked)

    def _mask_money_var(self, var: tk.StringVar) -> None:
        if self._mask_updating:
            return
        digits = self._digits_only(var.get())
        if not digits:
            return
        cents = int(digits)
        inteiro = cents // 100
        frac = cents % 100
        masked = f"{inteiro:,}".replace(",", ".") + f",{frac:02d}"
        if masked != var.get():
            self._set_var_safely(var, masked)

    def _build_command(self) -> list[str]:
        repo_wsl = windows_path_to_wsl(Path(__file__).resolve().parent)
        return ["wsl", "bash", "-lc", f"cd '{repo_wsl}' && COB_LIBRARY_PATH=bin ./bin/bankmain"]

    def start_session(self) -> None:
        if self.process and self.process.poll() is None:
            messagebox.showinfo("Informacao", "A sessao ja esta em execucao.")
            return
        try:
            self.process = subprocess.Popen(
                self._build_command(),
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
        except Exception as exc:
            messagebox.showerror("Erro", f"Falha ao iniciar sessao: {exc}")
            return
        self.status_var.set("Status: executando")
        self._append_output("[GUI] Sessao iniciada.\n")
        threading.Thread(target=self._reader_loop, daemon=True).start()

    def stop_session(self) -> None:
        if not self.process or self.process.poll() is not None:
            self.status_var.set("Status: parado")
            return
        try:
            if self.process.stdin:
                self.process.stdin.write("0\n")
                self.process.stdin.flush()
        except Exception:
            pass
        try:
            self.process.terminate()
            self.process.wait(timeout=2)
        except Exception:
            try:
                self.process.kill()
            except Exception:
                pass
        self.status_var.set("Status: parado")
        self._append_output("[GUI] Sessao encerrada.\n")

    def send_input(self, text: str) -> None:
        value = text.strip()
        self.input_var.set("")
        if not value:
            return
        if not self.process or self.process.poll() is not None:
            messagebox.showwarning("Atencao", "Inicie a sessao antes de enviar comandos.")
            return
        try:
            if self.process.stdin:
                self.process.stdin.write(value + "\n")
                self.process.stdin.flush()
            self._append_output(f"[VOCE] {value}\n")
        except Exception as exc:
            messagebox.showerror("Erro", f"Falha ao enviar entrada: {exc}")

    def send_sequence(self, values: list[str], delay: float = 0.08) -> None:
        if not self.process or self.process.poll() is not None:
            messagebox.showwarning("Atencao", "Inicie a sessao antes de enviar comandos.")
            return

        def _worker() -> None:
            for item in values:
                self.root.after(0, lambda v=item: self.send_input(v))
                time.sleep(delay)

        threading.Thread(target=_worker, daemon=True).start()

    def _digits_only(self, value: str) -> str:
        return "".join(ch for ch in value if ch.isdigit())

    def _normalize_money(self, value: str) -> str | None:
        raw = value.strip().replace(" ", "")
        if not raw:
            return None
        normalized = raw.replace(".", ",")
        if not re.fullmatch(r"-?\d+(,\d{1,2})?", normalized):
            return None
        return normalized

    def _validate_account_number(self, value: str) -> str | None:
        digits = self._digits_only(value)
        return digits or None

    def _validate_agency(self, value: str) -> str | None:
        digits = self._digits_only(value)
        return digits if len(digits) == 4 else None

    def _validate_cpf(self, value: str) -> str | None:
        digits = self._digits_only(value)
        return digits if len(digits) == 11 else None

    def open_account_flow(self) -> None:
        nome = self.open_nome_var.get().strip()
        cpf = self._validate_cpf(self.open_cpf_var.get())
        tipo = self.open_tipo_var.get().strip() or "CC"
        agencia = self._validate_agency(self.open_agencia_var.get())
        email = self.open_email_var.get().strip()
        telefone_digits = self._digits_only(self.open_telefone_var.get().strip())

        if not nome or not cpf or not agencia:
            messagebox.showwarning("Dados incompletos", "Preencha Nome, CPF valido e Agencia valida.")
            return
        if telefone_digits and not (8 <= len(telefone_digits) <= 15):
            messagebox.showwarning("Telefone invalido", "Informe um telefone com 8 a 15 digitos.")
            return
        if email and "@" not in email:
            messagebox.showwarning("Email invalido", "Informe um email valido.")
            return

        steps = ["1", "01", nome, cpf, tipo, agencia, email, telefone_digits]
        if self.open_back_to_main_var.get():
            steps.extend(["00", "0"])
        self.send_sequence(steps)

    def consult_account_flow(self) -> None:
        conta = self._validate_account_number(self.consult_num_var.get().strip())
        if not conta:
            messagebox.showwarning("Conta invalida", "Informe o numero da conta (digitos).")
            return
        steps = ["1", "02", conta]
        if self.consult_back_to_main_var.get():
            steps.extend(["00", "0"])
        self.send_sequence(steps)

    def deposit_flow(self) -> None:
        conta = self._validate_account_number(self.dep_conta_var.get().strip())
        valor = self._normalize_money(self.dep_valor_var.get().strip())
        if not conta or not valor:
            messagebox.showwarning("Dados invalidos", "Informe conta e valor validos.")
            return
        steps = ["2", "01", conta, valor]
        if self.dep_back_to_main_var.get():
            steps.extend(["00", "0"])
        self.send_sequence(steps)

    def withdraw_flow(self) -> None:
        conta = self._validate_account_number(self.saq_conta_var.get().strip())
        valor = self._normalize_money(self.saq_valor_var.get().strip())
        if not conta or not valor:
            messagebox.showwarning("Dados invalidos", "Informe conta e valor validos.")
            return
        steps = ["2", "02", conta, valor]
        if self.saq_back_to_main_var.get():
            steps.extend(["00", "0"])
        self.send_sequence(steps)

    def transfer_flow(self) -> None:
        tipo = self.trf_tipo_var.get().strip() or "TED"
        origem = self._validate_account_number(self.trf_origem_var.get().strip())
        valor = self._normalize_money(self.trf_valor_var.get().strip())
        if not origem or not valor:
            messagebox.showwarning("Transferencia", "Informe origem e valor validos.")
            return

        if tipo in ("TED", "DOC"):
            destino = self._validate_account_number(self.trf_destino_var.get().strip())
            if not destino:
                messagebox.showwarning("Transferencia", "Informe conta destino valida para TED/DOC.")
                return
            op = "01" if tipo == "TED" else "02"
            steps = ["4", op, origem, destino, valor]
        else:
            chave_tipo = self.trf_pix_tipo_var.get().strip() or "C"
            chave = self.trf_pix_chave_var.get().strip()
            if not chave:
                messagebox.showwarning("PIX", "Informe a chave PIX.")
                return
            if chave_tipo == "C":
                chave = self._digits_only(chave)
                if len(chave) != 11:
                    messagebox.showwarning("PIX", "CPF da chave PIX deve ter 11 digitos.")
                    return
            elif chave_tipo == "T":
                chave = self._digits_only(chave)
                if not (8 <= len(chave) <= 15):
                    messagebox.showwarning("PIX", "Telefone da chave PIX invalido.")
                    return
            steps = ["4", "03", origem, chave_tipo, chave, valor]

        if self.trf_back_to_main_var.get():
            steps.extend(["00", "0"])
        self.send_sequence(steps)

    def payment_flow(self) -> None:
        conta = self._validate_account_number(self.pay_conta_var.get().strip())
        codigo = self._digits_only(self.pay_codigo_var.get().strip())
        valor = self._normalize_money(self.pay_valor_var.get().strip())

        if not conta or not valor:
            messagebox.showwarning("Pagamento", "Informe conta e valor validos.")
            return
        if len(codigo) != 44:
            messagebox.showwarning("Pagamento", "Codigo de barras deve ter 44 digitos.")
            return

        steps = ["5", "01", conta, codigo, valor]
        if self.pay_back_to_main_var.get():
            steps.extend(["00", "0"])
        self.send_sequence(steps)

    def report_flow(self) -> None:
        tipo = self.rep_tipo_var.get().strip() or "01"
        steps = ["8", tipo]
        if self.rep_back_to_main_var.get():
            steps.extend(["00", "0"])
        self.send_sequence(steps)

    def investment_cdb_flow(self) -> None:
        valor = self._normalize_money(self.inv_valor_var.get().strip())
        prazo = self._digits_only(self.inv_prazo_var.get().strip())
        if not valor or not prazo:
            messagebox.showwarning("Investimento", "Informe valor e prazo validos.")
            return
        confirm = "S" if self.inv_confirmar_var.get() else "N"
        steps = ["6", "01", valor, prazo, confirm]
        if self.inv_back_to_main_var.get():
            steps.extend(["00", "0"])
        self.send_sequence(steps)

    def export_flow(self) -> None:
        formats = [fmt for fmt, var in self._exp_fmt_vars.items() if var.get()]
        if not formats:
            messagebox.showwarning("Exportar", "Selecione ao menos um formato.")
            return

        raw_text: str = self.output.get("1.0", tk.END)
        if len(raw_text.strip()) < 10:
            messagebox.showwarning("Exportar", "Nenhum conteúdo na saída para exportar.")
            return

        out_dir = Path(self.exp_dir_var.get().strip() or "exports")
        stem = self.exp_stem_var.get().strip() or "extrato"

        def _run() -> None:
            records = parse_extrato_lines(raw_text)
            results = export_formats(records, formats, out_dir, stem, raw_text=raw_text)
            lines = [f"Exportação concluída — {len(records)} transação(ões) detectadas\n"]
            for fmt, ok in results.items():
                icon = "✓" if ok else "✗ (dep. ausente)"
                lines.append(f"  {icon}  {fmt.upper():6} → {out_dir / f'{stem}.{fmt}'}")
            msg = "\n".join(lines)
            self.root.after(0, lambda: messagebox.showinfo("Exportar", msg))

        threading.Thread(target=_run, daemon=True).start()

    def loan_flow(self) -> None:
        op = self.loan_op_var.get().strip() or "01"
        conta = self._digits_only(self.loan_conta_var.get().strip())
        tipo = self.loan_tipo_var.get().strip() or "PES"
        valor = self._normalize_money(self.loan_valor_var.get().strip())
        parcelas = self._digits_only(self.loan_parcelas_var.get().strip())
        emp_id = self._digits_only(self.loan_id_var.get().strip())

        steps = ["A", op]
        if op == "01":
            if not conta or not valor or not parcelas:
                messagebox.showwarning("Emprestimo", "Informe conta, valor e parcelas.")
                return
            steps += [conta, tipo, valor, parcelas, "S"]
        elif op in ("02", "03", "06"):
            if not emp_id:
                messagebox.showwarning("Emprestimo", "Informe o ID do emprestimo.")
                return
            steps += [emp_id]
            if op == "03":
                steps.append("S")
            elif op == "06":
                steps.append("S")
        elif op == "04":
            if not valor or not parcelas:
                messagebox.showwarning("Simulacao", "Informe valor e parcelas.")
                return
            steps += [tipo, valor, parcelas]
        elif op == "05":
            if not conta:
                messagebox.showwarning("Emprestimo", "Informe o numero da conta.")
                return
            steps.append(conta)

        if self.loan_back_var.get():
            steps.extend(["00", "0"])
        self.send_sequence(steps)

    def card_flow(self) -> None:
        op = self.card_op_var.get().strip() or "01"
        conta = self._digits_only(self.card_conta_var.get().strip())
        tipo = self.card_tipo_var.get().strip() or "D"
        limite = self._normalize_money(self.card_limite_var.get().strip())
        num = self._digits_only(self.card_num_var.get().strip())
        valor = self._normalize_money(self.card_valor_var.get().strip())

        steps = ["B", op]
        if op == "01":
            if not conta:
                messagebox.showwarning("Cartao", "Informe o numero da conta.")
                return
            steps += [conta, tipo]
            if tipo == "C":
                if not limite:
                    messagebox.showwarning("Cartao", "Informe o limite de credito.")
                    return
                steps.append(limite)
        elif op in ("02", "03", "04", "06"):
            if not num:
                messagebox.showwarning("Cartao", "Informe o numero do cartao.")
                return
            steps.append(num)
        elif op == "05":
            if not num or not limite:
                messagebox.showwarning("Cartao", "Informe cartao e novo limite.")
                return
            steps += [num, limite]
        elif op == "07":
            if not num:
                messagebox.showwarning("Cartao", "Informe o numero do cartao.")
                return
            steps.append(num)
            pagar_total = "S" if not valor else "N"
            steps.append(pagar_total)
            if pagar_total == "N" and valor:
                steps.append(valor)
        elif op == "08":
            if not conta:
                messagebox.showwarning("Cartao", "Informe o numero da conta.")
                return
            steps.append(conta)

        if self.card_back_var.get():
            steps.extend(["00", "0"])
        self.send_sequence(steps)

    def schedule_flow(self) -> None:
        op = self.schd_op_var.get().strip() or "01"
        conta = self._digits_only(self.schd_conta_var.get().strip())
        tipo = self.schd_tipo_var.get().strip() or "TED"
        dest = self._digits_only(self.schd_dest_var.get().strip())
        valor = self._normalize_money(self.schd_valor_var.get().strip())
        data = self._digits_only(self.schd_data_var.get().strip())
        rec = self.schd_rec_var.get().strip() or "U"
        agend_id = self._digits_only(self.schd_id_var.get().strip())

        steps = ["C", op]
        if op == "01":
            if not conta or not valor or not data:
                messagebox.showwarning("Agendamento", "Informe conta, valor e data.")
                return
            steps += [conta, tipo, dest or "0", valor, data, rec]
        elif op == "02":
            if not conta or not valor or not data:
                messagebox.showwarning("Agendamento", "Informe conta, valor e data.")
                return
            steps += [conta, valor, data, "Pagamento agendado"]
        elif op == "03":
            if not conta:
                messagebox.showwarning("Agendamento", "Informe o numero da conta.")
                return
            steps.append(conta)
        elif op == "04":
            if not agend_id:
                messagebox.showwarning("Agendamento", "Informe o ID do agendamento.")
                return
            steps.append(agend_id)
        # op 05: no extra input needed

        if self.schd_back_var.get():
            steps.extend(["00", "0"])
        self.send_sequence(steps)

    def clear_output(self) -> None:
        self.output.configure(state=tk.NORMAL)
        self.output.delete("1.0", tk.END)
        self.output.configure(state=tk.DISABLED)

    def _reader_loop(self) -> None:
        if not self.process or not self.process.stdout:
            return
        for line in self.process.stdout:
            self.output_queue.put(line)
        self.output_queue.put("\n[GUI] Processo finalizado.\n")
        self.status_var.set("Status: parado")

    def _schedule_queue_drain(self) -> None:
        self._drain_output_queue()
        self.root.after(60, self._schedule_queue_drain)

    def _drain_output_queue(self) -> None:
        while True:
            try:
                line = self.output_queue.get_nowait()
            except queue.Empty:
                break
            self._append_output(line)

    def _append_output(self, text: str) -> None:
        self.output.configure(state=tk.NORMAL)
        self.output.insert(tk.END, text)
        self.output.see(tk.END)
        self.output.configure(state=tk.DISABLED)

    def on_close(self) -> None:
        self.stop_session()
        self.root.destroy()


def main() -> None:
    root = tk.Tk()
    BankGuiApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
