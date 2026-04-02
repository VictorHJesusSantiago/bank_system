# BANK SYSTEM

<div align="center">

Um sistema bancario modular em COBOL com GUI em Python, persistencia em arquivos indexados e fluxo de automacao para testes de regressao.

<br><br>

![Build](https://img.shields.io/badge/build-GnuCOBOL-2ea44f?style=for-the-badge)
![GUI](https://img.shields.io/badge/interface-Tkinter-1f6feb?style=for-the-badge)
![Tests](https://img.shields.io/badge/regressao-E2E%20automatizada-f59e0b?style=for-the-badge)

</div>

## Visao Geral

O projeto implementa um conjunto de rotinas bancarias separadas por responsabilidade, com um orquestrador principal e modulos especializados para contas, transacoes, consultas, transferencias, pagamentos, clientes, relatorios e administracao.

Os dados sao persistidos em arquivos indexados e o uso normal pode ser feito tanto pelo terminal quanto por uma interface grafica dedicada.

## Destaques

| Area | O que entrega |
| --- | --- |
| Core COBOL | Orquestracao central via `BANKMAIN` e modulos especializados |
| Contas | Abertura, consulta, atualizacao, bloqueio, encerramento e listagem |
| Transacoes | Deposito, saque, TED, DOC, PIX e registro historico |
| Pagamentos | Pagamento de boleto com validacao de codigo de barras |
| Clientes | Cadastro, consulta, atualizacao, inativacao e listagem |
| GUI | `bank_gui.py` para operar sem o fluxo manual do terminal |
| Regressao | Scripts automatizados de verificacao funcional |

## Estrutura

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
└── Makefile
```

## Requisitos

- GnuCOBOL (`cobc`)
- Python 3.10+ com `tkinter`
- `make`
- WSL ou ambiente Linux para executar os testes automatizados com `pty`

## Atalhos Principais

| Comando | O que faz |
| --- | --- |
| `make all` | Compila todos os modulos COBOL e gera `bin/bankmain` |
| `make run` | Executa o sistema pelo terminal |
| `make run-gui` | Abre a interface grafica |
| `make acceptance` | Compila e roda a regressao completa |
| `make acceptance-fast` | Roda a regressao completa sem recompilar |
| `make acceptance-finance` | Roda apenas os cenarios financeiros |

## Execucao Rapida

### Linha de comando

```bash
make all
make run
```

### Interface grafica

```bash
make run-gui
```

### Regressao automatizada

```bash
make acceptance
make acceptance-fast
make acceptance-finance
```

## Testes

Os scripts de regressao usam pseudo-terminal para interagir com os programas COBOL de forma confiavel.

- `acceptance_regression.py` valida deposito, TED, DOC, PIX, boleto e CRUD de clientes.
- `finance_regression.py` valida apenas os fluxos financeiros.

## Observacoes

- Os arquivos `.DAT`, `.LOG` e `.TXT` sao gerados em tempo de execucao e ficam fora do controle de versao.
- O diretorio `bin/` contem os binarios e modulos compilados.
- Se algum comando COBOL reclamar de biblioteca ausente, rode pelo `make` para garantir que `COB_LIBRARY_PATH` seja configurado corretamente.

## Fluxo Recomendado

1. `make all`
2. `make acceptance-fast`
3. `make run-gui`

## Licenca

Projeto interno de estudo e evolucao de sistema bancario em COBOL.
