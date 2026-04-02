# BANK SYSTEM

<div align="center">

<h1>Core banking in COBOL</h1>
<h3>Modular banking platform with GUI, indexed files, and automated acceptance flows.</h3>

<p>
<img src="https://img.shields.io/badge/GnuCOBOL-2ea44f?style=for-the-badge" alt="GnuCOBOL">
<img src="https://img.shields.io/badge/Tkinter-1f6feb?style=for-the-badge" alt="Tkinter">
<img src="https://img.shields.io/badge/E2E%20Regression-f59e0b?style=for-the-badge" alt="E2E Regression">
<img src="https://img.shields.io/badge/Status-Stable-2ea44f?style=for-the-badge" alt="Status Stable">
</p>

</div>

> Sistema bancario orientado a modulos: contas, transacoes, consultas, transferencias, pagamentos, clientes, relatorios e administracao.
>
> Operacao por terminal ou por interface grafica, com regressao automatizada para os fluxos mais importantes.

<table>
<tr>
<td width="25%" align="center">

<img src="https://img.shields.io/badge/Language-COBOL-005b96?style=for-the-badge" alt="Language">

<br><br>

<b>Enterprise logic</b><br>
Classic record-driven business rules split into modules.

</td>
<td width="25%" align="center">

<img src="https://img.shields.io/badge/Frontend-Python%20GUI-6f42c1?style=for-the-badge" alt="Frontend">

<br><br>

<b>Operator friendly</b><br>
Menu guidance, validation, and streamlined flows.

</td>
<td width="25%" align="center">

<img src="https://img.shields.io/badge/Storage-Indexed%20Files-0f766e?style=for-the-badge" alt="Storage">

<br><br>

<b>Persistent state</b><br>
Account, client, and transaction data lives in indexed files.

</td>
<td width="25%" align="center">

<img src="https://img.shields.io/badge/Automation-PTY%20Test%20Runner-d97706?style=for-the-badge" alt="Automation">

<br><br>

<b>Regression ready</b><br>
Functional checks run through a pseudo-terminal.

</td>
</tr>
</table>

<table>
<tr>
<td width="50%" valign="top">

### Panorama

The project separates each responsibility into a dedicated COBOL module, with `BANKMAIN` acting as the orchestrator. The data layer is file-backed and the usage model is designed to work across terminal, GUI, and regression suites.

This is not a demo shell. The repository now includes operational flows for account lifecycle, transaction processing, transfers, payments, customer management, reports, and administrative operations.

</td>
<td width="50%" valign="top">

### Destaques Visuais

<ul>
<li><b>Interface:</b> `bank_gui.py` com fluxo guiado</li>
<li><b>Automacao:</b> regressao com pseudo-terminal</li>
<li><b>Persistencia:</b> arquivos `.DAT`, `.LOG` e `.TXT`</li>
<li><b>Build:</b> compilacao via `Makefile`</li>
<li><b>Targets:</b> `acceptance`, `acceptance-fast`, `acceptance-finance`</li>
</ul>

</td>
</tr>
</table>

## Project Map

<table>
<tr>
<th align="left">Module</th>
<th align="left">Role</th>
<th align="left">Notes</th>
</tr>
<tr>
<td><code>BANKMAIN.cob</code></td>
<td>Entry point and workflow router</td>
<td>Coordinates menu flow and dispatches modules</td>
</tr>
<tr>
<td><code>BANKACCT.cob</code></td>
<td>Account lifecycle</td>
<td>Open, consult, update, block, close, list</td>
</tr>
<tr>
<td><code>BANKTRAN.cob</code></td>
<td>Money movement</td>
<td>Deposit, withdrawal, transfer and transaction history</td>
</tr>
<tr>
<td><code>BANKTRF.cob</code></td>
<td>Transfer engine</td>
<td>TED, DOC and PIX routing with validations</td>
</tr>
<tr>
<td><code>BANKPAY.cob</code></td>
<td>Bill payment</td>
<td>Boleto payment with barcode checks</td>
</tr>
<tr>
<td><code>BANKCRM.cob</code></td>
<td>Customer management</td>
<td>Register, consult, update, inactivate, list</td>
</tr>
<tr>
<td><code>BANKQRY.cob</code></td>
<td>Queries and statements</td>
<td>Balance and extraction helper flows</td>
</tr>
<tr>
<td><code>BANKREP.cob</code></td>
<td>Reporting</td>
<td>Structured reporting output</td>
</tr>
<tr>
<td><code>BANKADM.cob</code></td>
<td>Administration</td>
<td>Operational and maintenance actions</td>
</tr>
<tr>
<td><code>bank_gui.py</code></td>
<td>Desktop interface</td>
<td>Modern operational wrapper around COBOL flows</td>
</tr>
</table>

## Feature Cards

<table>
<tr>
<td width="33%" valign="top">

<img src="https://img.shields.io/badge/Contas-2563eb?style=for-the-badge" alt="Contas">

<br><br>

Open, consult, update, block, close and list accounts with indexed persistence.

</td>
<td width="33%" valign="top">

<img src="https://img.shields.io/badge/Transacoes-7c3aed?style=for-the-badge" alt="Transacoes">

<br><br>

Deposit, withdrawal, TED, DOC, PIX and transaction history with rule checks.

</td>
<td width="33%" valign="top">

<img src="https://img.shields.io/badge/Pagamentos-f97316?style=for-the-badge" alt="Pagamentos">

<br><br>

Bill payment with barcode validation and account debit flow.

</td>
</tr>
<tr>
<td width="33%" valign="top">

<img src="https://img.shields.io/badge/Clientes-0f766e?style=for-the-badge" alt="Clientes">

<br><br>

Customer register, consult, update, inactivate and list.

</td>
<td width="33%" valign="top">

<img src="https://img.shields.io/badge/GUI-1f6feb?style=for-the-badge" alt="GUI">

<br><br>

Python GUI for operating without the manual terminal menu.

</td>
<td width="33%" valign="top">

<img src="https://img.shields.io/badge/Testes-f59e0b?style=for-the-badge" alt="Testes">

<br><br>

Complete and finance-only regressions with deterministic `PASS/FAIL` output.

</td>
</tr>
</table>

## File Layout

```text
.
├── BANKMAIN.cob
├── BANKACCT.cob
├── BANKTRAN.cob
├── BANKQRY.cob
├── BANKTRF.cob
├── BANKPAY.cob
├── BANKCRM.cob
├── BANKREP.cob
├── BANKADM.cob
├── BANKINV.cob
├── BANKDATA.cpy
├── bank_gui.py
├── acceptance_regression.py
├── finance_regression.py
├── Makefile
└── .gitignore
```

## Execution Flow

<table>
<tr>
<td width="33%" valign="top">

### 1. Build

Compile all modules and link the executable.

```bash
make all
```

</td>
<td width="33%" valign="top">

### 2. Run

Launch the terminal flow or the GUI.

```bash
make run
make run-gui
```

</td>
<td width="33%" valign="top">

### 3. Validate

Run acceptance checks for the whole stack or just finance.

```bash
make acceptance-fast
make acceptance-finance
```

</td>
</tr>
</table>

## Estrutura do Projeto

```text
.
├── BANKMAIN.cob
├── BANKACCT.cob
├── BANKTRAN.cob
├── BANKQRY.cob
├── BANKTRF.cob
├── BANKPAY.cob
├── BANKCRM.cob
├── BANKREP.cob
├── BANKADM.cob
├── BANKINV.cob
├── BANKDATA.cpy
├── bank_gui.py
├── acceptance_regression.py
├── finance_regression.py
├── Makefile
└── .gitignore
```

## Requisitos

<table>
<tr>
<td>

- GnuCOBOL (`cobc`)
- Python 3.10+ com `tkinter`
- `make`
- Git

</td>
<td>

- WSL ou Linux para `pty`
- Estrutura de binarios em `bin/`
- Permissao para executar scripts Python
- Terminal capaz de executar `script` ou `python3`

</td>
</tr>
</table>

## Comandos Principais

<table>
<tr>
<th align="left">Command</th>
<th align="left">Effect</th>
</tr>
<tr>
<td><code>make all</code></td>
<td>Compila todos os modulos COBOL e gera <code>bin/bankmain</code></td>
</tr>
<tr>
<td><code>make run</code></td>
<td>Executa o sistema pelo terminal</td>
</tr>
<tr>
<td><code>make run-gui</code></td>
<td>Abre a interface grafica</td>
</tr>
<tr>
<td><code>make acceptance</code></td>
<td>Compila e roda a regressao completa</td>
</tr>
<tr>
<td><code>make acceptance-fast</code></td>
<td>Roda a regressao completa sem recompilar</td>
</tr>
<tr>
<td><code>make acceptance-finance</code></td>
<td>Roda apenas os cenarios financeiros</td>
</tr>
</table>

## Visual Flow

<table>
<tr>
<td width="50%" valign="top">

### Terminal mode

- Ideal for quick debugging
- Useful for menu-driven operations
- Best for low-level COBOL flow tracing

</td>
<td width="50%" valign="top">

### GUI mode

- Better for demonstrations
- Reduces manual terminal input
- Provides guided forms and validations

</td>
</tr>
</table>

## Run Examples

### Fluxo normal

```bash
make all
make run
```

### Interface grafica

```bash
make run-gui
```

### Regressao

```bash
make acceptance
make acceptance-fast
make acceptance-finance
```

## Testes Automatizados

Os scripts de regressao usam pseudo-terminal para interagir com os programas COBOL de forma confiavel.

- `acceptance_regression.py` valida deposito, TED, DOC, PIX, boleto e CRUD de clientes.
- `finance_regression.py` valida apenas os fluxos financeiros.

### Coverage Matrix

<table>
<tr>
<th align="left">Scenario</th>
<th align="left">Target</th>
<th align="left">Signal</th>
</tr>
<tr>
<td>Financial flows</td>
<td><code>acceptance-finance</code></td>
<td><code>PASS</code> for deposit, TED, DOC, PIX, boleto</td>
</tr>
<tr>
<td>Full acceptance</td>
<td><code>acceptance-fast</code></td>
<td>Includes customer CRUD plus finance flows</td>
</tr>
<tr>
<td>Build + acceptance</td>
<td><code>acceptance</code></td>
<td>Rebuilds first, then runs the suite</td>
</tr>
</table>

## Observacoes de Uso

<div align="center">

<img src="https://img.shields.io/badge/Arquivos%20Gerados-.DAT%20%7C%20.LOG%20%7C%20.TXT-6b7280?style=for-the-badge" alt="Arquivos Gerados">
<img src="https://img.shields.io/badge/Binarios-bin%2F-6b7280?style=for-the-badge" alt="Binarios">
<img src="https://img.shields.io/badge/Automacao-COB_LIBRARY_PATH-6b7280?style=for-the-badge" alt="Automacao">

</div>

- Os arquivos `.DAT`, `.LOG` e `.TXT` sao gerados em tempo de execucao e ficam fora do controle de versao.
- O diretorio `bin/` contem os binarios e modulos compilados.
- Se algum comando COBOL reclamar de biblioteca ausente, rode pelo `make` para garantir que `COB_LIBRARY_PATH` esteja correto.
- Se um fluxo interativo travar em automacao simples, use o runner de regressao que ja aplica pseudo-terminal.

## Troubleshooting

<table>
<tr>
<td width="50%" valign="top">

### Common issue

`module not found` or missing COBOL modules at runtime.

### Fix

Run through `make run` or `make acceptance`, which sets the module path correctly.

</td>
<td width="50%" valign="top">

### Common issue

Interactive flows do not consume piped input.

### Fix

Use the regression scripts, which drive the app through a pseudo-terminal.

</td>
</tr>
</table>

## Operational Notes

<table>
<tr>
<td width="33%" align="center">

<img src="https://img.shields.io/badge/Data%20Files-Generated%20at%20Runtime-8b5cf6?style=for-the-badge" alt="Data Files">

</td>
<td width="33%" align="center">

<img src="https://img.shields.io/badge/Build%20Output-bin%2F-0ea5e9?style=for-the-badge" alt="Build Output">

</td>
<td width="33%" align="center">

<img src="https://img.shields.io/badge/Regression-Deterministic-22c55e?style=for-the-badge" alt="Regression">

</td>
</tr>
</table>

- The `.DAT`, `.LOG`, and `.TXT` files are runtime artifacts and stay out of version control.
- The `bin/` directory holds generated executables and shared modules.
- If a COBOL command complains about missing libraries, let `make` handle the environment.

## Fluxo Recomendado

1. `make all`
2. `make acceptance-fast`
3. `make run-gui`

## Suggested Next Steps

1. Add screenshots of the GUI.
2. Add a short architecture diagram.
3. Add sample account and transfer scenarios.

## Licenca

Projeto interno de estudo e evolucao de sistema bancario em COBOL.
