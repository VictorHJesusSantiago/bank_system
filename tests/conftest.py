import os
import sys
import time
import select
import subprocess

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BANKMAIN = os.path.join(ROOT, "bin", "bankmain")
LIBPATH = os.path.join(ROOT, "bin")

if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

try:
    import pty

    HAS_PTY = True
except ImportError:
    HAS_PTY = False


@pytest.fixture(autouse=True)
def _ephemeral_vault_key(monkeypatch, tmp_path_factory):
    """Fornece uma KEK descartável por sessão de teste (ADR-001).

    Em produção a ausência de chave é erro: o cofre não gera mais uma chave em
    disco sozinho. Nos testes a chave é aleatória, vive só no ambiente do
    processo e some com ele — nenhum arquivo `.master.key` é criado.
    """
    import base64
    import secrets

    monkeypatch.setenv("BANK_MASTER_KEY", base64.urlsafe_b64encode(secrets.token_bytes(32)).decode())


MAIN_BANNER = "SISTEMA BANCARIO COBOL"
EXIT_MESSAGE = "Encerrando sessao..."
FATAL_ERROR_MARKER = "ERRO FATAL"

REGULATORY_KEYWORDS = (
    "Regulatorio",
    "IRRF",
    "CCF",
    "2FA",
    "FGTS",
    "Tributario",
    "DAS",
    "Sinistro",
    "Apolice",
    "Compensacao",
    "Declaracao",
)

MODULES = {
    "BANKACCT": {
        "key": "1",
        "title": "GESTAO DE CONTAS",
        "options": [
            ("01", "Abrir Nova Conta"),
            ("02", "Consultar Conta"),
            ("03", "Atualizar Dados"),
            ("04", "Bloquear/Desbloquear Conta"),
            ("05", "Encerrar Conta"),
            ("06", "Listar Todas as Contas"),
            ("07", "Buscar por CPF"),
            ("08", "Aplicar Tarifa de Manutencao"),
            ("09", "Relatorio de Contas"),
            ("00", "Voltar"),
        ],
    },
    "BANKTRAN": {
        "key": "2",
        "title": "TRANSACOES BANCARIAS",
        "options": [
            ("01", "Deposito"),
            ("02", "Saque"),
            ("03", "Transferencia (TED)"),
            ("04", "Transferencia (DOC)"),
            ("05", "PIX"),
            ("06", "Pagamento de Boleto"),
            ("07", "Consultar Saldo"),
            ("08", "Extrato (30 dias)"),
            ("09", "Estornar Transacao"),
            ("00", "Voltar"),
        ],
    },
    "BANKQRY": {
        "key": "3",
        "title": "CONSULTAS E EXTRATOS",
        "options": [
            ("01", "Consultar conta por numero"),
            ("02", "Consultar conta por CPF"),
            ("03", "Extrato rapido por conta"),
            ("00", "Voltar"),
        ],
    },
    "BANKTRF": {
        "key": "4",
        "title": "TRANSFERENCIAS",
        "options": [
            ("01", "TED (taxa R$ 14,90)"),
            ("02", "DOC (taxa R$ 5,80)"),
            ("03", "PIX (taxa R$ 0,00)"),
            ("04", "Cadastrar Chave PIX Aleatoria"),
            ("00", "Voltar"),
        ],
    },
    "BANKPAY": {
        "key": "5",
        "title": "PAGAMENTOS E BOLETOS",
        "options": [
            ("01", "Pagar Boleto"),
            ("02", "Emitir Boleto"),
            ("03", "Consultar Boletos da Conta"),
            ("00", "Voltar"),
        ],
    },
    "BANKINV": {
        "key": "6",
        "title": "INVESTIMENTOS",
        "options": [
            ("01", "Aplicar em CDB"),
            ("02", "Aplicar em LCI (Isento IR)"),
            ("03", "Aplicar em LCA (Isento IR)"),
            ("04", "Aplicar em Tesouro Direto"),
            ("05", "Aplicar em Fundo de Investimento"),
            ("06", "Resgatar Investimento"),
            ("07", "Consultar Carteira"),
            ("08", "Simular Investimento"),
            ("09", "Relatorio de Rentabilidade"),
            ("00", "Voltar"),
        ],
    },
    "BANKCRM": {
        "key": "7",
        "title": "GESTAO DE CLIENTES",
        "options": [
            ("01", "Cadastrar cliente (completo)"),
            ("02", "Consultar cliente por ID"),
            ("03", "Atualizar cadastro"),
            ("04", "Inativar cliente"),
            ("05", "Listar clientes"),
            ("00", "Voltar"),
        ],
    },
    "BANKREP": {
        "key": "8",
        "title": "RELATORIOS",
        "options": [
            ("01", "Balancete Geral"),
            ("02", "Resumo de Contas por Tipo"),
            ("03", "Movimentacao Diaria"),
            ("04", "Contas com Saldo Negativo"),
            ("05", "Top 10 Maiores Saldos"),
            ("06", "Relatorio de Inadimplencia"),
            ("07", "DRE Simplificado"),
            ("08", "Relatorio Regulatorio BCB"),
            ("00", "Voltar"),
        ],
    },
    "BANKADM": {
        "key": "9",
        "title": "ADMINISTRACAO",
        "options": [
            ("01", "Estatisticas gerais"),
            ("02", "Limpar arquivo de log"),
            ("00", "Voltar"),
        ],
    },
    "BANKLOAN": {
        "key": "A",
        "title": "EMPRESTIMOS E FINANCIAMENTOS",
        "options": [
            ("01", "Solicitar Emprestimo"),
            ("02", "Consultar Emprestimo"),
            ("03", "Pagar Parcela"),
            ("04", "Simular Emprestimo"),
            ("05", "Listar por Conta"),
            ("06", "Quitacao Antecipada"),
            ("00", "Voltar"),
        ],
    },
    "BANKCARD": {
        "key": "B",
        "title": "CARTOES BANCARIOS",
        "options": [
            ("01", "Emitir Cartao"),
            ("02", "Consultar Cartao"),
            ("03", "Bloquear Cartao"),
            ("04", "Desbloquear Cartao"),
            ("05", "Alterar Limite de Credito"),
            ("06", "Consultar Fatura"),
            ("07", "Pagar Fatura"),
            ("08", "Listar Cartoes da Conta"),
            ("09", "Cartao Virtual (fixo por conta)"),
            ("10", "Compra no Debito"),
            ("11", "Compra no Credito"),
            ("12", "Compra Parcelada"),
            ("00", "Voltar"),
        ],
    },
    "BANKSCHD": {
        "key": "C",
        "title": "AGENDAMENTOS",
        "options": [
            ("01", "Agendar Transferencia (TED/DOC/PIX)"),
            ("02", "Agendar Pagamento de Boleto"),
            ("03", "Listar Agendamentos da Conta"),
            ("04", "Cancelar Agendamento"),
            ("05", "Processar Pendentes de Hoje"),
            ("00", "Voltar"),
        ],
    },
    "BANKAUTH": {
        "key": "D",
        "title": "AUTENTICACAO E SEGURANCA",
        "options": [
            ("01", "Login (CPF + Senha)"),
            ("02", "Alterar Senha"),
            ("03", "Verificacao em Dois Fatores (2FA)"),
            ("04", "Recuperar Acesso"),
            ("05", "Minha Pontuacao e Badges"),
            ("00", "Voltar"),
        ],
    },
    "BANKFX": {
        "key": "E",
        "title": "CAMBIO E MOEDAS",
        "options": [
            ("01", "Comprar Moeda Estrangeira"),
            ("02", "Vender Moeda Estrangeira"),
            ("03", "Consultar Cotacoes"),
            ("04", "Transferencia Internacional (SWIFT)"),
            ("05", "Historico de Operacoes"),
            ("00", "Voltar"),
        ],
    },
    "BANKSEG": {
        "key": "F",
        "title": "SEGUROS",
        "options": [
            ("01", "Contratar Seguro de Vida"),
            ("02", "Contratar Seguro Auto"),
            ("03", "Contratar Seguro Residencia"),
            ("04", "Contratar Seguro Viagem"),
            ("05", "Consultar Apolices"),
            ("06", "Acionar Sinistro"),
            ("07", "Cancelar Apolice"),
            ("00", "Voltar"),
        ],
    },
    "BANKCONS": {
        "key": "G",
        "title": "CONSORCIO",
        "options": [
            ("01", "Aderir Consorcio Imovel"),
            ("02", "Aderir Consorcio Veiculo"),
            ("03", "Aderir Consorcio Servicos"),
            ("04", "Consultar Cotas"),
            ("05", "Oferecer Lance"),
            ("06", "Historico de Contemplados"),
            ("07", "Simulador de Consorcio"),
            ("00", "Voltar"),
        ],
    },
    "BANKHELP": {
        "key": "H",
        "title": "CENTRAL DE AJUDA — BANCO COBOL",
        "options": [
            ("01", "Perguntas Frequentes (FAQ)"),
            ("02", "Guia de Uso Rapido"),
            ("03", "Termos de Uso"),
            ("04", "Politica de Privacidade"),
            ("05", "Fale Conosco / Suporte"),
            ("06", "Sobre o Sistema"),
            ("00", "Voltar"),
        ],
    },
    "BANKPREV": {
        "key": "I",
        "title": "PREVIDENCIA PRIVADA",
        "options": [
            ("01", "Contratar PGBL"),
            ("02", "Contratar VGBL"),
            ("03", "Aporte Extraordinario"),
            ("04", "Portabilidade entre planos"),
            ("05", "Resgatar"),
            ("06", "Extrato e Projecao"),
            ("00", "Voltar"),
        ],
    },
    "BANKDEB": {
        "key": "J",
        "title": "DEBITO AUTOMATICO",
        "options": [
            ("01", "Cadastrar Debito Automatico"),
            ("02", "Consultar Debitos Ativos"),
            ("03", "Suspender Debito"),
            ("04", "Reativar Debito"),
            ("05", "Cancelar Debito"),
            ("06", "Historico de Execucoes"),
            ("07", "Executar Debitos Pendentes"),
            ("00", "Voltar"),
        ],
    },
    "BANKCAP": {
        "key": "K",
        "title": "TITULO DE CAPITALIZACAO",
        "options": [
            ("01", "Adquirir Titulo"),
            ("02", "Consultar Titulos"),
            ("03", "Pagar Mensalidade"),
            ("04", "Participar de Sorteio"),
            ("05", "Resgatar Titulo"),
            ("06", "Titulos Premiados"),
            ("00", "Voltar"),
        ],
    },
    "BANKLIM": {
        "key": "L",
        "title": "GESTAO DE LIMITES DE CREDITO",
        "options": [
            ("01", "Consultar Limite Atual"),
            ("02", "Solicitar Aumento de Limite"),
            ("03", "Reduzir Limite"),
            ("04", "Limite Emergencial (24h)"),
            ("05", "Bloqueio Temporario de Limite"),
            ("06", "Historico de Alteracoes"),
            ("00", "Voltar"),
        ],
    },
    "BANKNOTIF": {
        "key": "M",
        "title": "NOTIFICACOES E ALERTAS",
        "options": [
            ("01", "Configurar Alertas da Conta"),
            ("02", "Consultar Configuracao Atual"),
            ("03", "Ativar/Desativar Alertas"),
            ("04", "Testar Notificacao"),
            ("05", "Desativar Todos os Alertas"),
            ("00", "Voltar"),
        ],
    },
    "BANKTAX": {
        "key": "N",
        "title": "INFORME DE RENDIMENTOS - IMPOSTO DE RENDA",
        "options": [
            ("01", "Gerar Informe de Rendimentos"),
            ("02", "Rendimentos por Categoria"),
            ("03", "IRRF - Imposto Retido na Fonte"),
            ("04", "Saldo em 31/12"),
            ("05", "Movimentacoes para Declaracao"),
            ("00", "Voltar"),
        ],
    },
    "BANKCHQ": {
        "key": "O",
        "title": "TALAO DE CHEQUES",
        "options": [
            ("01", "Solicitar Novo Talao"),
            ("02", "Emitir Cheque"),
            ("03", "Cancelar/Sustar Cheque"),
            ("04", "Consultar Cheques da Conta"),
            ("05", "Verificar Compensacao"),
            ("06", "Cheques Devolvidos (CCF)"),
            ("00", "Voltar"),
        ],
    },
    "BANKFGTS": {
        "key": "P",
        "title": "FGTS - FUNDO DE GARANTIA",
        "options": [
            ("01", "Vincular Conta FGTS"),
            ("02", "Consultar Saldo FGTS"),
            ("03", "Saque-Aniversario"),
            ("04", "Antecipar FGTS (credito)"),
            ("05", "Simular Antecipacao"),
            ("06", "Extrato de Movimentacoes"),
            ("00", "Voltar"),
        ],
    },
    "BANKCOB": {
        "key": "Q",
        "title": "COBRANCA BANCARIA",
        "options": [
            ("01", "Emitir Titulo de Cobranca"),
            ("02", "Consultar Titulos"),
            ("03", "Liquidar Titulo"),
            ("04", "Cancelar Titulo"),
            ("05", "Relatorio de Inadimplencia"),
            ("06", "Prorrogar Vencimento"),
            ("00", "Voltar"),
        ],
    },
    "BANKOVD": {
        "key": "R",
        "title": "CHEQUE ESPECIAL / CREDITO ROTATIVO",
        "options": [
            ("01", "Consultar Saldo e Limite"),
            ("02", "Usar Credito Rotativo"),
            ("03", "Pagar/Reduzir Saldo Devedor"),
            ("04", "Extrato Cheque Especial"),
            ("05", "Simulacao de Juros"),
            ("06", "Solicitar Aumento de Limite"),
            ("00", "Voltar"),
        ],
    },
    "BANKPOUP": {
        "key": "S",
        "title": "CAIXINHAS / COFRINHOS",
        "options": [
            ("01", "Criar Caixinha"),
            ("02", "Depositar na Caixinha"),
            ("03", "Resgatar da Caixinha"),
            ("04", "Consultar Caixinhas da Conta"),
            ("05", "Alterar Meta"),
            ("06", "Encerrar Caixinha"),
            ("00", "Voltar"),
        ],
    },
    "BANKCONSIG": {
        "key": "T",
        "title": "CREDITO CONSIGNADO",
        "options": [
            ("01", "Consultar Margem Consignavel"),
            ("02", "Simular Consignado"),
            ("03", "Contratar Consignado"),
            ("04", "Consultar Contratos"),
            ("05", "Pagar Parcela"),
            ("06", "Quitacao Antecipada"),
            ("00", "Voltar"),
        ],
    },
    "BANKSCORE": {
        "key": "U",
        "title": "SCORE DE CREDITO",
        "options": [
            ("01", "Consultar Meu Score"),
            ("02", "Calcular/Atualizar Score"),
            ("03", "Detalhamento dos Fatores"),
            ("04", "Simular Impacto de Nova Divida"),
            ("05", "Dicas para Melhorar o Score"),
            ("00", "Voltar"),
        ],
    },
    "BANKCASHBACK": {
        "key": "V",
        "title": "CASHBACK E PROGRAMA DE FIDELIDADE",
        "options": [
            ("01", "Registrar Compra com Cashback"),
            ("02", "Consultar Saldo de Cashback/Pontos"),
            ("03", "Resgatar Cashback (creditar em conta)"),
            ("04", "Trocar Pontos por Beneficios"),
            ("05", "Extrato de Cashback"),
            ("06", "Meu Nivel de Fidelidade"),
            ("00", "Voltar"),
        ],
    },
    "BANKRENEG": {
        "key": "W",
        "title": "RENEGOCIACAO DE DIVIDAS",
        "options": [
            ("01", "Simular Renegociacao"),
            ("02", "Fechar Acordo"),
            ("03", "Consultar Acordos"),
            ("04", "Pagar Parcela do Acordo"),
            ("05", "Quitar Acordo a Vista"),
            ("00", "Voltar"),
        ],
    },
    "BANKPORT": {
        "key": "X",
        "title": "PORTABILIDADE",
        "options": [
            ("01", "Portabilidade de Salario"),
            ("02", "Portabilidade de Credito/Emprestimo"),
            ("03", "Portabilidade de Conta"),
            ("04", "Consultar Solicitacoes"),
            ("05", "Cancelar Solicitacao"),
            ("00", "Voltar"),
        ],
    },
    "BANKPJ": {
        "key": "Y",
        "title": "CONTA DIGITAL PJ / MEI",
        "options": [
            ("01", "Abrir Conta PJ/MEI"),
            ("02", "Consultar Dados da Empresa"),
            ("03", "Emitir Guia DAS (MEI)"),
            ("04", "Registrar Faturamento Mensal"),
            ("05", "Relatorio Simplificado p/ Contador"),
            ("06", "Consultar Enquadramento Tributario"),
            ("00", "Voltar"),
        ],
    },
    "BANKDOA": {
        "key": "Z",
        "title": "DOACOES E CONTRIBUICOES SOCIAIS",
        "options": [
            ("01", "Fazer Doacao"),
            ("02", "Configurar Doacao Recorrente"),
            ("03", "Consultar Historico de Doacoes"),
            ("04", "Emitir Recibo (Dedutivel do IR)"),
            ("05", "Instituicoes Parceiras"),
            ("06", "Cancelar Doacao Recorrente"),
            ("00", "Voltar"),
        ],
    },
}


def run_session(inputs, timeout=10.0, delay=0.05):
    if not HAS_PTY:
        pytest.skip("pty indisponivel nesta plataforma (requer Linux/WSL)")
    if not os.path.exists(BANKMAIN):
        pytest.skip("bin/bankmain nao encontrado - execute 'make' primeiro")

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

    output_chunks = []
    start = time.time()
    index = 0

    try:
        while time.time() - start < timeout:
            if index < len(inputs):
                time.sleep(delay)
                os.write(master_fd, (str(inputs[index]) + "\n").encode())
                index += 1

            ready, _, _ = select.select([master_fd], [], [], 0.05)
            if master_fd in ready:
                try:
                    data = os.read(master_fd, 8192)
                except OSError:
                    break
                if not data:
                    break
                output_chunks.append(data.decode(errors="ignore"))

            if proc.poll() is not None and index >= len(inputs):
                break
    finally:
        if proc.poll() is None:
            proc.terminate()
            time.sleep(0.2)
            if proc.poll() is None:
                proc.kill()
        try:
            os.close(master_fd)
        except OSError:
            pass

    return "".join(output_chunks)


def _module_so_path(name):
    return os.path.join(LIBPATH, f"{name}.so")


def _require(*names):
    if not HAS_PTY:
        pytest.skip("pty indisponivel nesta plataforma (requer Linux/WSL)")
    if not os.path.exists(BANKMAIN):
        pytest.skip("bin/bankmain nao encontrado - execute 'make' primeiro")
    for name in names:
        if not os.path.exists(_module_so_path(name)):
            pytest.skip(f"{name}.so nao compilado - execute 'make'")


def _enter(key, *sub_inputs, exit_system=True):
    inputs = [key, *sub_inputs, "00"]
    if exit_system:
        inputs.append("0")
    return run_session(inputs)


@pytest.fixture
def check_unit_menu_banner():
    def _check(name):
        _require(name)
        spec = MODULES[name]
        out = _enter(spec["key"])
        assert spec["title"] in out

    return _check


@pytest.fixture
def check_component_full_menu():
    def _check(name):
        _require(name)
        spec = MODULES[name]
        out = _enter(spec["key"])
        assert spec["title"] in out
        for _, desc in spec["options"]:
            assert desc in out
        assert out.count(MAIN_BANNER) >= 2

    return _check


@pytest.fixture
def check_integration_big_bang():
    def _check(name):
        spec = MODULES[name]
        keys = list(MODULES.keys())
        idx = keys.index(name)
        prev_spec = MODULES[keys[idx - 1]]
        next_spec = MODULES[keys[(idx + 1) % len(keys)]]
        _require(name, keys[idx - 1], keys[(idx + 1) % len(keys)])
        inputs = [
            prev_spec["key"],
            "00",
            spec["key"],
            "00",
            next_spec["key"],
            "00",
            "0",
        ]
        out = run_session(inputs, timeout=15.0)
        assert prev_spec["title"] in out
        assert spec["title"] in out
        assert next_spec["title"] in out

    return _check


@pytest.fixture
def check_integration_top_down():
    def _check(name):
        _require(name)
        spec = MODULES[name]
        out = run_session([spec["key"], "00", "0"])
        main_idx = out.find(MAIN_BANNER)
        module_idx = out.find(spec["title"])
        assert main_idx != -1
        assert module_idx != -1
        assert main_idx < module_idx

    return _check


@pytest.fixture
def check_integration_bottom_up():
    def _check(name):
        _require(name)
        spec = MODULES[name]
        first_code, _ = spec["options"][0]
        out = run_session([spec["key"], first_code, "00", "0"])
        assert spec["title"] in out
        assert out.count(MAIN_BANNER) >= 2

    return _check


@pytest.fixture
def check_integration_sandwich():
    def _check(name):
        _require(name)
        spec = MODULES[name]
        first_code, _ = spec["options"][0]
        out = run_session([spec["key"], "00", spec["key"], first_code, "00", "0"], timeout=15.0)
        assert out.count(spec["title"]) >= 2
        assert out.count(MAIN_BANNER) >= 2

    return _check


@pytest.fixture
def check_system_e2e():
    def _check(name):
        _require(name)
        spec = MODULES[name]
        out = run_session([spec["key"], "00", "0"], timeout=15.0)
        assert MAIN_BANNER in out
        assert spec["title"] in out
        assert EXIT_MESSAGE in out

    return _check


@pytest.fixture
def check_acceptance_uat():
    def _check(name):
        _require(name)
        spec = MODULES[name]
        out = _enter(spec["key"])
        assert spec["title"] in out
        assert spec["options"][0][1] in out
        assert spec["options"][-1][1] in out

    return _check


@pytest.fixture
def check_acceptance_alpha():
    def _check(name):
        _require(name)
        spec = MODULES[name]
        out = run_session([spec["key"], "99", "00", "0"])
        assert FATAL_ERROR_MARKER not in out
        assert spec["title"] in out
        assert MAIN_BANNER in out

    return _check


@pytest.fixture
def check_acceptance_beta():
    def _check(name):
        _require(name)
        spec = MODULES[name]
        out = run_session([spec["key"], "", "00", "0"])
        assert spec["title"] in out
        assert FATAL_ERROR_MARKER not in out

    return _check


@pytest.fixture
def check_acceptance_operational():
    def _check(name):
        _require(name)
        spec = MODULES[name]
        out = run_session([spec["key"], "00", "0"], timeout=15.0)
        assert EXIT_MESSAGE in out
        assert "Operacoes realizadas" in out
        assert FATAL_ERROR_MARKER not in out

    return _check


@pytest.fixture
def check_acceptance_regulatory():
    def _check(name):
        _require(name)
        spec = MODULES[name]
        out = _enter(spec["key"])
        matches = [
            desc
            for _, desc in spec["options"]
            if any(kw.lower() in desc.lower() for kw in REGULATORY_KEYWORDS)
        ]
        if matches:
            for desc in matches:
                assert desc in out
        else:
            assert spec["title"] in out

    return _check
