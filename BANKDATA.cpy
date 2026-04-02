      *================================================================
      * BANKDATA.CPY - Estruturas de Dados Compartilhadas
      * Sistema Bancário COBOL - Copybook Principal
      * Versão: 2.0 | Arquitetura: MVC em Camadas
      *================================================================

      *----------------------------------------------------------------
      * ESTRUTURA DE CONTA BANCÁRIA
      *----------------------------------------------------------------
       01  WS-CONTA.
           05  WS-CONTA-NUM         PIC 9(10).
           05  WS-CONTA-AGENCIA     PIC 9(4).
           05  WS-CONTA-DIGITO      PIC 9(1).
           05  WS-CONTA-TIPO        PIC X(2).
               88  CONTA-CORRENTE   VALUE 'CC'.
               88  CONTA-POUPANCA   VALUE 'CP'.
               88  CONTA-SALARIO    VALUE 'CS'.
               88  CONTA-INVESTIMENTO VALUE 'CI'.
           05  WS-CONTA-STATUS      PIC X(1).
               88  CONTA-ATIVA      VALUE 'A'.
               88  CONTA-BLOQUEADA  VALUE 'B'.
               88  CONTA-ENCERRADA  VALUE 'E'.
               88  CONTA-PENDENTE   VALUE 'P'.
           05  WS-CONTA-SALDO       PIC S9(13)V99 COMP-3.
           05  WS-CONTA-LIMITE      PIC S9(11)V99 COMP-3.
           05  WS-CONTA-TITULAR     PIC X(60).
           05  WS-CONTA-CPF         PIC X(11).
           05  WS-CONTA-EMAIL       PIC X(80).
           05  WS-CONTA-TELEFONE    PIC X(15).
           05  WS-CONTA-DT-ABERTURA PIC 9(8).
           05  WS-CONTA-DT-ATUALIZACAO PIC 9(8).
           05  WS-CONTA-SENHA-HASH  PIC X(64).

      *----------------------------------------------------------------
      * ESTRUTURA DE TRANSAÇÃO
      *----------------------------------------------------------------
       01  WS-TRANSACAO.
           05  WS-TRANS-ID          PIC 9(15).
           05  WS-TRANS-CONTA-ORG   PIC 9(10).
           05  WS-TRANS-CONTA-DEST  PIC 9(10).
           05  WS-TRANS-TIPO        PIC X(3).
               88  TRANS-DEPOSITO   VALUE 'DEP'.
               88  TRANS-SAQUE      VALUE 'SAQ'.
               88  TRANS-TRANSFERE  VALUE 'TRF'.
               88  TRANS-PAGAMENTO  VALUE 'PAG'.
               88  TRANS-PIX        VALUE 'PIX'.
               88  TRANS-TED        VALUE 'TED'.
               88  TRANS-DOC        VALUE 'DOC'.
               88  TRANS-RENDIMENTO VALUE 'REN'.
               88  TRANS-TARIFA     VALUE 'TAR'.
           05  WS-TRANS-VALOR       PIC S9(13)V99 COMP-3.
           05  WS-TRANS-DATA        PIC 9(8).
           05  WS-TRANS-HORA        PIC 9(6).
           05  WS-TRANS-DESCRICAO   PIC X(100).
           05  WS-TRANS-STATUS      PIC X(1).
               88  TRANS-PENDENTE   VALUE 'P'.
               88  TRANS-EFETIVADA  VALUE 'E'.
               88  TRANS-CANCELADA  VALUE 'C'.
               88  TRANS-ESTORNADA  VALUE 'X'.
           05  WS-TRANS-NSU         PIC 9(12).
           05  WS-TRANS-CANAL       PIC X(10).

      *----------------------------------------------------------------
      * ESTRUTURA DE CLIENTE
      *----------------------------------------------------------------
       01  WS-CLIENTE.
           05  WS-CLI-ID            PIC 9(10).
           05  WS-CLI-NOME          PIC X(60).
           05  WS-CLI-CPF           PIC X(14).
           05  WS-CLI-RG            PIC X(15).
           05  WS-CLI-DT-NASC       PIC 9(8).
           05  WS-CLI-SEXO          PIC X(1).
               88  SEXO-MASCULINO   VALUE 'M'.
               88  SEXO-FEMININO    VALUE 'F'.
               88  SEXO-OUTRO       VALUE 'O'.
           05  WS-CLI-ESTADO-CIVIL  PIC X(2).
           05  WS-CLI-PROFISSAO     PIC X(40).
           05  WS-CLI-RENDA         PIC S9(11)V99 COMP-3.
           05  WS-CLI-PERFIL-RISCO  PIC X(1).
               88  RISCO-CONSERVADOR  VALUE 'C'.
               88  RISCO-MODERADO     VALUE 'M'.
               88  RISCO-ARROJADO     VALUE 'A'.
           05  WS-CLI-ENDERECO.
               10  WS-CLI-LOGRADOURO PIC X(60).
               10  WS-CLI-NUMERO    PIC X(10).
               10  WS-CLI-COMPL     PIC X(30).
               10  WS-CLI-BAIRRO    PIC X(40).
               10  WS-CLI-CIDADE    PIC X(40).
               10  WS-CLI-ESTADO    PIC X(2).
               10  WS-CLI-CEP       PIC X(8).
           05  WS-CLI-STATUS        PIC X(1).
               88  CLI-ATIVO        VALUE 'A'.
               88  CLI-INATIVO      VALUE 'I'.
               88  CLI-BLOQUEADO    VALUE 'B'.
           05  WS-CLI-SCORE-CREDITO PIC 9(4).

      *----------------------------------------------------------------
      * ESTRUTURA DE RETORNO PADRÃO
      *----------------------------------------------------------------
       01  WS-RETORNO.
           05  WS-RET-CODIGO        PIC 9(4).
               88  SUCESSO          VALUE 0000.
               88  ERRO-SALDO       VALUE 0001.
               88  ERRO-CONTA       VALUE 0002.
               88  ERRO-LIMITE      VALUE 0003.
               88  ERRO-BLOQUEIO    VALUE 0004.
               88  ERRO-AUTH        VALUE 0005.
               88  ERRO-SISTEMA     VALUE 9999.
           05  WS-RET-MENSAGEM      PIC X(100).
           05  WS-RET-TIMESTAMP     PIC X(26).

      *----------------------------------------------------------------
      * ESTRUTURA DE INVESTIMENTO
      *----------------------------------------------------------------
       01  WS-INVESTIMENTO.
           05  WS-INV-ID            PIC 9(10).
           05  WS-INV-CONTA         PIC 9(10).
           05  WS-INV-PRODUTO       PIC X(30).
           05  WS-INV-TIPO          PIC X(3).
               88  INV-CDB          VALUE 'CDB'.
               88  INV-LCI          VALUE 'LCI'.
               88  INV-LCA          VALUE 'LCA'.
               88  INV-TESOURO      VALUE 'TES'.
               88  INV-FUNDO        VALUE 'FDO'.
           05  WS-INV-VALOR-APORT   PIC S9(13)V99 COMP-3.
           05  WS-INV-VALOR-ATUAL   PIC S9(13)V99 COMP-3.
           05  WS-INV-TAXA          PIC S9(5)V9(6) COMP-3.
           05  WS-INV-DT-INICIO     PIC 9(8).
           05  WS-INV-DT-VENCTO     PIC 9(8).
           05  WS-INV-RENTABILIDADE PIC S9(5)V99 COMP-3.
