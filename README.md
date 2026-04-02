# BANK SYSTEM

<div align="center">

<h3>Banco modular em COBOL, com GUI em Python, arquivos indexados e testes automatizados.</h3>

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
<td width="50%" valign="top">

### Panorama

O projeto separa cada responsabilidade em um modulo COBOL dedicado, com `BANKMAIN` atuando como orquestrador. Os dados ficam em arquivos indexados e a experiencia de uso foi pensada para funcionar em terminais, GUI e suites de teste.

</td>
<td width="50%" valign="top">

### Destaques Visuais

<ul>
<li><b>Interface:</b> `bank_gui.py` com fluxo guiado</li>
<li><b>Automacao:</b> regressao com pseudo-terminal</li>
<li><b>Persistencia:</b> arquivos `.DAT`, `.LOG` e `.TXT`</li>
<li><b>Build:</b> compilacao via `Makefile`</li>
</ul>

</td>
</tr>
</table>

## Cartao de Funcionalidades

<table>
<tr>
<td width="33%" valign="top">

<img src="https://img.shields.io/badge/Contas-2563eb?style=for-the-badge" alt="Contas">

<br><br>

Abertura, consulta, atualizacao, bloqueio, encerramento e listagem de contas com persistencia indexada.

</td>
<td width="33%" valign="top">

<img src="https://img.shields.io/badge/Transacoes-7c3aed?style=for-the-badge" alt="Transacoes">

<br><br>

Deposito, saque, TED, DOC, PIX e registro de historico com validacoes operacionais.

</td>
<td width="33%" valign="top">

<img src="https://img.shields.io/badge/Pagamentos-f97316?style=for-the-badge" alt="Pagamentos">

<br><br>

Pagamento de boleto com validacao de codigo de barras e fluxo de debito em conta.

</td>
</tr>
<tr>
<td width="33%" valign="top">

<img src="https://img.shields.io/badge/Clientes-0f766e?style=for-the-badge" alt="Clientes">

<br><br>

Cadastro, consulta, atualizacao, inativacao e listagem de clientes.

</td>
<td width="33%" valign="top">

<img src="https://img.shields.io/badge/GUI-1f6feb?style=for-the-badge" alt="GUI">

<br><br>

Interface grafica em Python para operar sem depender do menu manual do terminal.

</td>
<td width="33%" valign="top">

<img src="https://img.shields.io/badge/Testes-f59e0b?style=for-the-badge" alt="Testes">

<br><br>

Regressoes completas e financeiras com saida objetiva `PASS/FAIL`.

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

</td>
<td>

- WSL ou Linux para `pty`
- Estrutura de binarios em `bin/`
- Permissao para executar scripts Python

</td>
</tr>
</table>

## Comandos Principais

<table>
<tr>
<th>Comando</th>
<th>Resultado</th>
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

## Execucao

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

## Observacoes de Uso

<div align="center">

<img src="https://img.shields.io/badge/Arquivos%20Gerados-.DAT%20%7C%20.LOG%20%7C%20.TXT-6b7280?style=for-the-badge" alt="Arquivos Gerados">
<img src="https://img.shields.io/badge/Binarios-bin%2F-6b7280?style=for-the-badge" alt="Binarios">
<img src="https://img.shields.io/badge/Automacao-COB_LIBRARY_PATH-6b7280?style=for-the-badge" alt="Automacao">

</div>

- Os arquivos `.DAT`, `.LOG` e `.TXT` sao gerados em tempo de execucao e ficam fora do controle de versao.
- O diretorio `bin/` contem os binarios e modulos compilados.
- Se algum comando COBOL reclamar de biblioteca ausente, rode pelo `make` para garantir que `COB_LIBRARY_PATH` esteja correto.

## Fluxo Recomendado

1. `make all`
2. `make acceptance-fast`
3. `make run-gui`

## Licenca

Projeto interno de estudo e evolucao de sistema bancario em COBOL.
