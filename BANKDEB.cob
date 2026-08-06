       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKDEB.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQDEB ASSIGN TO 'BANKDEB.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS DEB-ID
               FILE STATUS IS FS-DEB.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQDEB.
       01  REG-DEB.
           05  DEB-ID                PIC 9(12).
           05  DEB-CONTA             PIC 9(10).
           05  DEB-BENEFICIARIO      PIC X(60).
           05  DEB-CNPJ-CPF          PIC X(14).
           05  DEB-DESCRICAO         PIC X(80).
           05  DEB-VALOR             PIC S9(11)V99 COMP-3.
           05  DEB-DIA-VENCTO        PIC 9(2).
           05  DEB-TIPO              PIC X(1).
           05  DEB-STATUS            PIC X(1).
           05  DEB-DT-CADASTRO       PIC 9(8).
           05  DEB-DT-ULT-EXEC       PIC 9(8).
           05  DEB-CTR-EXECUCOES     PIC 9(6).
           05  DEB-CTR-FALHAS        PIC 9(4).

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-DEB-CTRL.
           05  FS-DEB                PIC XX.
               88  FS-DEB-OK         VALUE '00'.
               88  FS-DEB-EOF        VALUE '10'.
               88  FS-DEB-NFD        VALUE '23'.
           05  FS-BRIDGE             PIC XX.
               88  FS-BRIDGE-OK      VALUE '00'.
               88  FS-BRIDGE-EOF     VALUE '10'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  DEB-PARAR         VALUE 'N'.
           05  WS-DEB-SEQ            PIC 9(12) VALUE ZEROS.

       01  WS-BRIDGE.
           05  WS-BR-OUTFILE          PIC X(40).
           05  WS-BR-CMD              PIC X(250).
           05  WS-BR-CONTA-E          PIC Z(9)9.
           05  WS-BR-ID-E             PIC Z(11)9.
           05  WS-BR-VALOR-INT-N      PIC 9(11).
           05  WS-BR-VALOR-INT-E      PIC Z(10)9.
           05  WS-BR-VALOR-DEC        PIC 99.
           05  WS-BR-VALOR-STR        PIC X(20).
           05  WS-BR-LINE             PIC X(200).
           05  WS-BR-KEY              PIC X(30).
           05  WS-BR-VAL              PIC X(160).
           05  WS-BR-OK               PIC 9 VALUE 0.
           05  WS-BR-ERROR            PIC X(150) VALUE SPACES.

       01  WS-DEB-CALC.
           05  WS-DEB-CONTA-NUM      PIC 9(10).
           05  WS-DEB-ID-SEL         PIC 9(12).
           05  WS-DIS                PIC ZZ.ZZZ.ZZZ,99-.
           05  WS-DEB-TOT            PIC S9(13)V99 COMP-3.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQDEB
           IF NOT FS-DEB-OK
               OPEN OUTPUT ARQDEB
               CLOSE ARQDEB
               OPEN I-O ARQDEB
           END-IF
           PERFORM 9900-SEQ
           PERFORM 1000-MENU UNTIL DEB-PARAR
           CLOSE ARQDEB
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-SEQ.
           MOVE 999999999999 TO DEB-ID
           START ARQDEB KEY <= DEB-ID
           READ ARQDEB PREVIOUS
           IF FS-DEB-OK
               MOVE DEB-ID TO WS-DEB-SEQ
           ELSE
               MOVE ZEROS TO WS-DEB-SEQ
           END-IF.

       1000-MENU SECTION.
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '        DEBITO AUTOMATICO'
           DISPLAY '========================================'
           DISPLAY ' 01. Cadastrar Debito Automatico'
           DISPLAY ' 02. Consultar Debitos Ativos'
           DISPLAY ' 03. Suspender Debito'
           DISPLAY ' 04. Reativar Debito'
           DISPLAY ' 05. Cancelar Debito'
           DISPLAY ' 06. Historico de Execucoes'
           DISPLAY ' 07. Executar Debitos Pendentes'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-CADASTRAR
               WHEN '02' PERFORM 3000-CONSULTAR
               WHEN '03' PERFORM 4000-SUSPENDER
               WHEN '04' PERFORM 4500-REATIVAR
               WHEN '05' PERFORM 5000-CANCELAR
               WHEN '06' PERFORM 6000-HISTORICO
               WHEN '07' PERFORM 7000-EXECUTAR-PENDENTES
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-CADASTRAR SECTION.
       2000-INICIO.
           DISPLAY '--- CADASTRAR DEBITO AUTOMATICO ---'
           DISPLAY 'Conta para debito: '
           ACCEPT WS-DEB-CONTA-NUM
           DISPLAY 'Beneficiario (empresa/credor): '
           ACCEPT DEB-BENEFICIARIO
           DISPLAY 'CNPJ/CPF do beneficiario: '
           ACCEPT DEB-CNPJ-CPF
           DISPLAY 'Descricao (ex: conta luz, internet): '
           ACCEPT DEB-DESCRICAO
           DISPLAY 'Tipo (F=Fixo V=Variavel): '
           ACCEPT DEB-TIPO
           DISPLAY 'Valor mensal (F=fixo; V=0 para variavel): '
           ACCEPT DEB-VALOR
           DISPLAY 'Dia de vencimento (1-28): '
           ACCEPT DEB-DIA-VENCTO
           IF DEB-DIA-VENCTO < 1 OR DEB-DIA-VENCTO > 28
               MOVE 5 TO DEB-DIA-VENCTO
               DISPLAY 'Dia ajustado para 5'
           END-IF
           MOVE DEB-VALOR TO WS-DIS
           DISPLAY 'Valor: R$ ' WS-DIS
           DISPLAY 'Vencimento: dia ' DEB-DIA-VENCTO
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               ADD 1 TO WS-DEB-SEQ
               MOVE WS-DEB-SEQ TO DEB-ID
               MOVE WS-DEB-CONTA-NUM TO DEB-CONTA
               MOVE 'A' TO DEB-STATUS
               MOVE FUNCTION CURRENT-DATE(1:8) TO DEB-DT-CADASTRO
               MOVE ZEROS TO DEB-DT-ULT-EXEC
                             DEB-CTR-EXECUCOES DEB-CTR-FALHAS
               WRITE REG-DEB
               IF FS-DEB-OK
                   DISPLAY 'DEBITO CADASTRADO! ID: ' DEB-ID
                   MOVE 0 TO LS-CODIGO
               ELSE
                   DISPLAY 'ERRO: ' FS-DEB
                   MOVE 9999 TO LS-CODIGO
               END-IF
           ELSE
               DISPLAY 'CANCELADO'
           END-IF.

       3000-CONSULTAR SECTION.
       3000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-DEB-CONTA-NUM
           MOVE ZEROS TO WS-DEB-TOT
           DISPLAY '========================================'
           DISPLAY ' ID            Beneficiario        Valor  Dia St'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO DEB-ID
           START ARQDEB KEY >= DEB-ID
           PERFORM UNTIL FS-DEB-EOF
               READ ARQDEB NEXT
               IF FS-DEB-OK
                   IF DEB-CONTA = WS-DEB-CONTA-NUM
                   AND DEB-STATUS = 'A'
                       MOVE DEB-VALOR TO WS-DIS
                       DISPLAY DEB-ID ' '
                               DEB-BENEFICIARIO(1:20) '  R$ '
                               WS-DIS ' '
                               DEB-DIA-VENCTO ' '
                               DEB-STATUS
                       ADD DEB-VALOR TO WS-DEB-TOT
                   END-IF
               END-IF
           END-PERFORM
           MOVE WS-DEB-TOT TO WS-DIS
           DISPLAY '----------------------------------------'
           DISPLAY ' Total mensal comprometido: R$ ' WS-DIS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       4000-SUSPENDER SECTION.
       4000-INICIO.
           DISPLAY 'ID do debito: '
           ACCEPT WS-DEB-ID-SEL
           MOVE WS-DEB-ID-SEL TO DEB-ID
           READ ARQDEB KEY IS DEB-ID
           IF FS-DEB-NFD
               DISPLAY 'DEBITO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE 'S' TO DEB-STATUS
           REWRITE REG-DEB
           DISPLAY 'DEBITO SUSPENSO: ' DEB-BENEFICIARIO(1:30)
           MOVE 0 TO LS-CODIGO.

       4500-REATIVAR.
           DISPLAY 'ID do debito: '
           ACCEPT WS-DEB-ID-SEL
           MOVE WS-DEB-ID-SEL TO DEB-ID
           READ ARQDEB KEY IS DEB-ID
           IF FS-DEB-NFD
               DISPLAY 'DEBITO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE 'A' TO DEB-STATUS
           REWRITE REG-DEB
           DISPLAY 'DEBITO REATIVADO: ' DEB-BENEFICIARIO(1:30)
           MOVE 0 TO LS-CODIGO.

       5000-CANCELAR SECTION.
       5000-INICIO.
           DISPLAY 'ID do debito: '
           ACCEPT WS-DEB-ID-SEL
           MOVE WS-DEB-ID-SEL TO DEB-ID
           READ ARQDEB KEY IS DEB-ID
           IF FS-DEB-NFD
               DISPLAY 'DEBITO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY DEB-BENEFICIARIO(1:40)
           DISPLAY 'Confirmar cancelamento? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'C' TO DEB-STATUS
               REWRITE REG-DEB
               DISPLAY 'DEBITO AUTOMATICO CANCELADO'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CANCELAMENTO ABORTADO'
           END-IF.

       6000-HISTORICO SECTION.
       6000-INICIO.
           DISPLAY 'ID do debito: '
           ACCEPT WS-DEB-ID-SEL
           MOVE WS-DEB-ID-SEL TO DEB-ID
           READ ARQDEB KEY IS DEB-ID
           IF FS-DEB-NFD
               DISPLAY 'DEBITO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY '========================================'
           DISPLAY ' Beneficiario: ' DEB-BENEFICIARIO(1:40)
           DISPLAY ' Status: ' DEB-STATUS
           DISPLAY ' Execucoes realizadas: ' DEB-CTR-EXECUCOES
           DISPLAY ' Falhas: ' DEB-CTR-FALHAS
           DISPLAY ' Ultima execucao: ' DEB-DT-ULT-EXEC
           MOVE DEB-VALOR TO WS-DIS
           DISPLAY ' Valor: R$ ' WS-DIS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       7000-EXECUTAR-PENDENTES SECTION.
       7000-INICIO.
           DISPLAY 'Conta para processar debitos: '
           ACCEPT WS-DEB-CONTA-NUM
           DISPLAY '--- Processando debitos do dia ---'
           MOVE ZEROS TO DEB-ID
           START ARQDEB KEY >= DEB-ID
           PERFORM UNTIL FS-DEB-EOF
               READ ARQDEB NEXT
               IF FS-DEB-OK
                   IF DEB-CONTA = WS-DEB-CONTA-NUM
                   AND DEB-STATUS = 'A'
                       MOVE DEB-VALOR TO WS-DIS
                       DISPLAY 'Debitando: ' DEB-BENEFICIARIO(1:30)
                               ' R$ ' WS-DIS
                       PERFORM 7100-DEBITAR-RAZAO
                       IF WS-BR-OK = 1
                           ADD 1 TO DEB-CTR-EXECUCOES
                       ELSE
                           ADD 1 TO DEB-CTR-FALHAS
                           DISPLAY 'FALHA NO RAZAO: ' WS-BR-ERROR
                       END-IF
                       MOVE FUNCTION CURRENT-DATE(1:8)
                           TO DEB-DT-ULT-EXEC
                       REWRITE REG-DEB
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY 'PROCESSAMENTO CONCLUIDO'
           MOVE 0 TO LS-CODIGO.

       7100-DEBITAR-RAZAO.
           MOVE DEB-CONTA TO WS-BR-CONTA-E
           MOVE DEB-ID TO WS-BR-ID-E
           COMPUTE WS-BR-VALOR-INT-N =
               FUNCTION INTEGER-PART(DEB-VALOR)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER(
                   (DEB-VALOR - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPD-' DEB-ID '.OUT' DELIMITED SIZE
               INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle DEB AUTOMATIC_DEBIT '
                  FUNCTION TRIM(WS-BR-CONTA-E) ' '
                  FUNCTION TRIM(WS-BR-VALOR-STR) ' '
                  FUNCTION TRIM(WS-BR-ID-E)
                  ' --cobol-out ' FUNCTION TRIM(WS-BR-OUTFILE)
                  DELIMITED SIZE INTO WS-BR-CMD
           CALL 'SYSTEM' USING WS-BR-CMD
           MOVE 0 TO WS-BR-OK
           MOVE SPACES TO WS-BR-ERROR
           OPEN INPUT ARQBRIDGE
           IF FS-BRIDGE-OK
               PERFORM UNTIL FS-BRIDGE-EOF
                   READ ARQBRIDGE INTO WS-BR-LINE
                   IF NOT FS-BRIDGE-EOF
                       MOVE SPACES TO WS-BR-KEY WS-BR-VAL
                       UNSTRING WS-BR-LINE DELIMITED BY '='
                           INTO WS-BR-KEY WS-BR-VAL
                       IF FUNCTION TRIM(WS-BR-KEY) = 'OK'
                           IF FUNCTION TRIM(WS-BR-VAL) = '1'
                               MOVE 1 TO WS-BR-OK
                           END-IF
                       END-IF
                       IF FUNCTION TRIM(WS-BR-KEY) = 'ERROR'
                           MOVE FUNCTION TRIM(WS-BR-VAL) TO WS-BR-ERROR
                       END-IF
                   END-IF
               END-PERFORM
               CLOSE ARQBRIDGE
           END-IF.

       9999-FIM.
           EXIT PROGRAM.
