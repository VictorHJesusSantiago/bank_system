      *================================================================
      * BANKMAIN.COB - Programa Principal / Orquestrador
      * Sistema Bancário COBOL - Ponto de Entrada
      * Padrão: Service Orchestrator Pattern
      * Versão: 2.0
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKMAIN.

      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-MAINFRAME.
       OBJECT-COMPUTER. IBM-MAINFRAME.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS REG-CONTA-NUM
               ALTERNATE RECORD KEY IS REG-CONTA-CPF WITH DUPLICATES
               FILE STATUS IS FS-CONTAS.

           SELECT ARQTRANS ASSIGN TO 'BANKTRAN.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS REG-TRANS-ID
               FILE STATUS IS FS-TRANS.

           SELECT ARQCLIENTE ASSIGN TO 'BANKCUST.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS REG-CLI-ID
               ALTERNATE RECORD KEY IS REG-CLI-CPF
               FILE STATUS IS FS-CLIENTE.

           SELECT ARQLOG ASSIGN TO 'BANKAUDT.LOG'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS FS-LOG.

      *----------------------------------------------------------------
       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONTAS.
       01  REG-CONTA.
           05  REG-CONTA-NUM         PIC 9(10).
           05  REG-CONTA-AGENCIA     PIC 9(4).
           05  REG-CONTA-DIGITO      PIC 9(1).
           05  REG-CONTA-TIPO        PIC X(2).
           05  REG-CONTA-STATUS      PIC X(1).
           05  REG-CONTA-SALDO       PIC S9(13)V99 COMP-3.
           05  REG-CONTA-LIMITE      PIC S9(11)V99 COMP-3.
           05  REG-CONTA-TITULAR     PIC X(60).
           05  REG-CONTA-CPF         PIC X(11).
           05  REG-CONTA-EMAIL       PIC X(80).
           05  REG-CONTA-TELEFONE    PIC X(15).
           05  REG-CONTA-DT-ABERTURA PIC 9(8).
           05  REG-CONTA-DT-ATUALIZACAO PIC 9(8).
           05  REG-CONTA-SENHA-HASH  PIC X(64).

       FD  ARQTRANS.
       01  REG-TRANS.
           05  REG-TRANS-ID          PIC 9(15).
           05  REG-TRANS-CONTA-ORG   PIC 9(10).
           05  REG-TRANS-CONTA-DEST  PIC 9(10).
           05  REG-TRANS-TIPO        PIC X(3).
           05  REG-TRANS-VALOR       PIC S9(13)V99 COMP-3.
           05  REG-TRANS-DATA        PIC 9(8).
           05  REG-TRANS-HORA        PIC 9(6).
           05  REG-TRANS-DESCRICAO   PIC X(100).
           05  REG-TRANS-STATUS      PIC X(1).
           05  REG-TRANS-NSU         PIC 9(12).
           05  REG-TRANS-CANAL       PIC X(10).

       FD  ARQCLIENTE.
       01  REG-CLIENTE.
           05  REG-CLI-ID            PIC 9(10).
           05  REG-CLI-NOME          PIC X(60).
           05  REG-CLI-CPF           PIC X(14).
           05  REG-CLI-RG            PIC X(15).
           05  REG-CLI-DT-NASC       PIC 9(8).
           05  REG-CLI-SEXO          PIC X(1).
           05  REG-CLI-ESTADO-CIVIL  PIC X(2).
           05  REG-CLI-PROFISSAO     PIC X(40).
           05  REG-CLI-RENDA         PIC S9(11)V99 COMP-3.
           05  REG-CLI-PERFIL-RISCO  PIC X(1).
           05  REG-CLI-ENDERECO.
               10  REG-CLI-LOGRADOURO PIC X(60).
               10  REG-CLI-NUMERO    PIC X(10).
               10  REG-CLI-COMPL     PIC X(30).
               10  REG-CLI-BAIRRO    PIC X(40).
               10  REG-CLI-CIDADE    PIC X(40).
               10  REG-CLI-ESTADO    PIC X(2).
               10  REG-CLI-CEP       PIC X(8).
           05  REG-CLI-STATUS        PIC X(1).
           05  REG-CLI-SCORE-CREDITO PIC 9(4).

       FD  ARQLOG.
       01  REG-LOG                  PIC X(200).

      *----------------------------------------------------------------
       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-FILE-STATUS.
           05  FS-CONTAS            PIC XX VALUE SPACES.
               88  FS-CONTA-OK      VALUE '00'.
               88  FS-CONTA-EOF     VALUE '10'.
               88  FS-CONTA-DUP     VALUE '22'.
               88  FS-CONTA-NFD     VALUE '23'.
           05  FS-TRANS             PIC XX VALUE SPACES.
               88  FS-TRANS-OK      VALUE '00'.
               88  FS-TRANS-EOF     VALUE '10'.
           05  FS-CLIENTE           PIC XX VALUE SPACES.
               88  FS-CLI-OK        VALUE '00'.
               88  FS-CLI-EOF       VALUE '10'.
           05  FS-LOG               PIC XX VALUE SPACES.

       01  WS-CONTROLE.
           05  WS-OPCAO             PIC X(3).
           05  WS-CONTINUAR         PIC X(1) VALUE 'S'.
               88  CONTINUAR-SIM    VALUE 'S' 'Y'.
               88  CONTINUAR-NAO    VALUE 'N'.
           05  WS-LOG-ATIVO         PIC X(1) VALUE 'N'.
           05  WS-VERSAO            PIC X(10) VALUE '2.0.0'.
           05  WS-AMBIENTE          PIC X(10) VALUE 'PRODUCAO'.
           05  WS-SESSION-ID        PIC X(32).
           05  WS-USUARIO-ID        PIC X(20).

       01  WS-DATETIME.
           05  WS-DATA-ATUAL        PIC 9(8).
           05  WS-HORA-ATUAL        PIC 9(6).
           05  WS-DATA-FORMAT       PIC X(10).
           05  WS-HORA-FORMAT       PIC X(8).

       01  WS-CONTADORES.
           05  WS-CTR-OPERACOES     PIC 9(10) VALUE ZEROS.
           05  WS-CTR-ERROS         PIC 9(6) VALUE ZEROS.
           05  WS-CTR-SESSOES       PIC 9(6) VALUE ZEROS.

       01  WS-METRICAS.
           05  WS-MET-TEMPO-RESP    PIC 9(6)V99 COMP-3.
           05  WS-MET-THROUGHPUT    PIC 9(8) COMP-3.
           05  WS-MET-DISPONIB      PIC 9(3)V99 COMP-3.

      *----------------------------------------------------------------
       PROCEDURE DIVISION.

      *================================================================
       0000-PRINCIPAL SECTION.
      *================================================================
       0000-INICIO.
           PERFORM 1000-INICIALIZAR
           PERFORM 2000-PROCESSAR UNTIL CONTINUAR-NAO
           PERFORM 9000-FINALIZAR
           STOP RUN.

      *================================================================
       1000-INICIALIZAR SECTION.
      *================================================================
       1000-INICIO.
           PERFORM 1100-ABRIR-ARQUIVOS
           PERFORM 1200-INICIALIZAR-SESSION
           PERFORM 1300-VERIFICAR-INTEGRIDADE
           PERFORM 1400-CARREGAR-CONFIGURACOES
           EXIT SECTION.

       1100-ABRIR-ARQUIVOS.
           OPEN EXTEND ARQLOG
           IF FS-LOG = '35'
               OPEN OUTPUT ARQLOG
               CLOSE ARQLOG
               OPEN EXTEND ARQLOG
           END-IF
           IF FS-LOG = '00'
               MOVE 'S' TO WS-LOG-ATIVO
           ELSE
               MOVE 'N' TO WS-LOG-ATIVO
               DISPLAY 'AVISO: LOG DESATIVADO (FS=' FS-LOG ')'
           END-IF.

       1200-INICIALIZAR-SESSION.
           MOVE FUNCTION CURRENT-DATE(1:8)  TO WS-DATA-ATUAL
           MOVE FUNCTION CURRENT-DATE(9:6)  TO WS-HORA-ATUAL
           MOVE FUNCTION RANDOM(WS-DATA-ATUAL)
                TO WS-SESSION-ID(1:10)
           ADD 1 TO WS-CTR-SESSOES.

       1300-VERIFICAR-INTEGRIDADE.
           PERFORM 1310-CHECK-CHECKSUM
           PERFORM 1320-CHECK-ESPACOS-DISCO.

       1310-CHECK-CHECKSUM.
           CONTINUE.

       1320-CHECK-ESPACOS-DISCO.
           CONTINUE.

       1400-CARREGAR-CONFIGURACOES.
           CONTINUE.

      *================================================================
       2000-PROCESSAR SECTION.
      *================================================================
       2000-INICIO.
           PERFORM 2100-EXIBIR-MENU
           PERFORM 2200-LER-OPCAO
           PERFORM 2300-EXECUTAR-OPERACAO
           EXIT SECTION.

       2100-EXIBIR-MENU.
           DISPLAY '================================================'
           DISPLAY '    SISTEMA BANCARIO COBOL v' WS-VERSAO
           DISPLAY '    Sessao: ' WS-SESSION-ID(1:8)
           DISPLAY '================================================'
           DISPLAY ' 1. Gestao de Contas'
           DISPLAY ' 2. Transacoes'
           DISPLAY ' 3. Consultas e Extratos'
           DISPLAY ' 4. Transferencias'
           DISPLAY ' 5. Pagamentos'
           DISPLAY ' 6. Investimentos'
           DISPLAY ' 7. Gestao de Clientes'
           DISPLAY ' 8. Relatorios'
           DISPLAY ' 9. Administracao'
           DISPLAY ' 0. Sair'
           DISPLAY '================================================'.

       2200-LER-OPCAO.
           MOVE SPACES TO WS-OPCAO
           ACCEPT WS-OPCAO.
           IF WS-OPCAO = SPACES
               MOVE '0' TO WS-OPCAO
           END-IF.

       2300-EXECUTAR-OPERACAO.
           EVALUATE WS-OPCAO(1:1)
               WHEN '1'
                   CALL 'BANKACCT' USING WS-RETORNO
               WHEN '2'
                   CALL 'BANKTRAN' USING WS-RETORNO
               WHEN '3'
                   CALL 'BANKQRY' USING WS-RETORNO
               WHEN '4'
                   CALL 'BANKTRF' USING WS-RETORNO
               WHEN '5'
                   CALL 'BANKPAY' USING WS-RETORNO
               WHEN '6'
                   CALL 'BANKINV' USING WS-RETORNO
               WHEN '7'
                   CALL 'BANKCRM' USING WS-RETORNO
               WHEN '8'
                   CALL 'BANKREP' USING WS-RETORNO
               WHEN '9'
                   CALL 'BANKADM' USING WS-RETORNO
               WHEN '0'
                   MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER
                   MOVE 'OPCAO INVALIDA' TO WS-RET-MENSAGEM
                   PERFORM 9800-EXIBIR-ERRO
           END-EVALUATE

           ADD 1 TO WS-CTR-OPERACOES
           PERFORM 9700-REGISTRAR-LOG.

      *================================================================
       9000-FINALIZAR SECTION.
      *================================================================
       9000-INICIO.
           PERFORM 9100-FECHAR-ARQUIVOS
           PERFORM 9200-GRAVAR-METRICAS
           PERFORM 9300-EXIBIR-SUMARIO.

       9100-FECHAR-ARQUIVOS.
           IF WS-LOG-ATIVO = 'S'
               CLOSE ARQLOG
           END-IF.

       9200-GRAVAR-METRICAS.
           CONTINUE.

       9300-EXIBIR-SUMARIO.
           DISPLAY 'Operacoes realizadas: ' WS-CTR-OPERACOES
           DISPLAY 'Erros encontrados: '    WS-CTR-ERROS
           DISPLAY 'Encerrando sessao...'
           EXIT SECTION.

       9700-REGISTRAR-LOG.
           IF WS-LOG-ATIVO = 'S'
               MOVE FUNCTION CURRENT-DATE(1:8) TO WS-DATA-ATUAL
               STRING WS-DATA-ATUAL DELIMITED SIZE
                      ' ' DELIMITED SIZE
                      WS-HORA-ATUAL DELIMITED SIZE
                      ' OP:' DELIMITED SIZE
                      WS-OPCAO DELIMITED SIZE
                      ' COD:' DELIMITED SIZE
                      WS-RET-CODIGO DELIMITED SIZE
                      INTO REG-LOG
               WRITE REG-LOG
           END-IF.

       9800-EXIBIR-ERRO.
           DISPLAY 'ERRO: ' WS-RET-MENSAGEM
           ADD 1 TO WS-CTR-ERROS.

       9900-TRATAR-ERRO-FATAL.
           DISPLAY 'ERRO FATAL: ' WS-RET-MENSAGEM
           STOP RUN.
