       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKPOUP.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQPOUP ASSIGN TO 'BANKPOUP.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS POUP-ID
               FILE STATUS IS FS-POUP.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQPOUP.
       01  REG-POUP.
           05  POUP-ID               PIC 9(12).
           05  POUP-CONTA            PIC 9(10).
           05  POUP-NOME             PIC X(40).
           05  POUP-META             PIC S9(11)V99 COMP-3.
           05  POUP-SALDO            PIC S9(11)V99 COMP-3.
           05  POUP-TAXA-CDI         PIC 9(3)V99 COMP-3.
           05  POUP-DT-CRIACAO       PIC 9(8).
           05  POUP-DT-META          PIC 9(8).
           05  POUP-STATUS           PIC X(1).

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-POUP-CTRL.
           05  FS-POUP               PIC XX.
               88  FS-POUP-OK        VALUE '00'.
               88  FS-POUP-EOF       VALUE '10'.
               88  FS-POUP-NFD       VALUE '23'.
           05  FS-BRIDGE             PIC XX.
               88  FS-BRIDGE-OK      VALUE '00'.
               88  FS-BRIDGE-EOF     VALUE '10'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  POUP-PARAR        VALUE 'N'.
           05  WS-POUP-SEQ           PIC 9(12) VALUE ZEROS.

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

       01  WS-POUP-CALC.
           05  WS-POUP-CONTA-NUM     PIC 9(10).
           05  WS-POUP-ID-SEL        PIC 9(12).
           05  WS-POUP-VALOR         PIC S9(11)V99 COMP-3.
           05  WS-POUP-PERC          PIC 9(3)V99 COMP-3.
           05  WS-POUP-CTR           PIC 9(6) COMP-3.
           05  WS-POUP-TOT-SALDO     PIC S9(13)V99 COMP-3.
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQPOUP
           IF NOT FS-POUP-OK
               OPEN OUTPUT ARQPOUP
               CLOSE ARQPOUP
               OPEN I-O ARQPOUP
           END-IF
           PERFORM 9900-SEQ
           PERFORM 1000-MENU UNTIL POUP-PARAR
           CLOSE ARQPOUP
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-SEQ.
           MOVE 999999999999 TO POUP-ID
           START ARQPOUP KEY <= POUP-ID
           READ ARQPOUP PREVIOUS
           IF FS-POUP-OK
               MOVE POUP-ID TO WS-POUP-SEQ
           ELSE
               MOVE ZEROS TO WS-POUP-SEQ
           END-IF.

       1000-MENU SECTION.
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '       CAIXINHAS / COFRINHOS'
           DISPLAY '========================================'
           DISPLAY ' 01. Criar Caixinha'
           DISPLAY ' 02. Depositar na Caixinha'
           DISPLAY ' 03. Resgatar da Caixinha'
           DISPLAY ' 04. Consultar Caixinhas da Conta'
           DISPLAY ' 05. Alterar Meta'
           DISPLAY ' 06. Encerrar Caixinha'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-CRIAR
               WHEN '02' PERFORM 3000-DEPOSITAR
               WHEN '03' PERFORM 4000-RESGATAR
               WHEN '04' PERFORM 5000-CONSULTAR
               WHEN '05' PERFORM 6000-ALTERAR-META
               WHEN '06' PERFORM 7000-ENCERRAR
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-CRIAR SECTION.
       2000-INICIO.
           DISPLAY '--- CRIAR CAIXINHA ---'
           DISPLAY 'Conta: '
           ACCEPT WS-POUP-CONTA-NUM
           DISPLAY 'Nome da caixinha (ex: Viagem, Reserva): '
           ACCEPT POUP-NOME
           DISPLAY 'Valor da meta (R$): '
           ACCEPT POUP-META
           DISPLAY 'Prazo da meta (AAAAMMDD): '
           ACCEPT POUP-DT-META
           DISPLAY 'Deposito inicial (R$): '
           ACCEPT POUP-SALDO
           ADD 1 TO WS-POUP-SEQ
           MOVE WS-POUP-SEQ TO POUP-ID
           MOVE WS-POUP-CONTA-NUM TO POUP-CONTA
           MOVE 1,0500 TO POUP-TAXA-CDI
           MOVE FUNCTION CURRENT-DATE(1:8) TO POUP-DT-CRIACAO
           MOVE 'A' TO POUP-STATUS
           WRITE REG-POUP
           IF FS-POUP-OK
               DISPLAY 'CAIXINHA CRIADA! ID: ' POUP-ID
               DISPLAY ' Rendimento: 105% do CDI'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO: ' FS-POUP
               MOVE 9999 TO LS-CODIGO
           END-IF.

       3000-DEPOSITAR SECTION.
       3000-INICIO.
           DISPLAY 'ID da Caixinha: '
           ACCEPT WS-POUP-ID-SEL
           MOVE WS-POUP-ID-SEL TO POUP-ID
           READ ARQPOUP KEY IS POUP-ID
           IF FS-POUP-NFD
               DISPLAY 'CAIXINHA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Valor a depositar (R$): '
           ACCEPT WS-POUP-VALOR
           PERFORM 3100-MOVIMENTAR-RAZAO
           IF WS-BR-OK NOT = 1
               DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
               MOVE 9998 TO LS-CODIGO
               EXIT SECTION
           END-IF
           ADD WS-POUP-VALOR TO POUP-SALDO
           REWRITE REG-POUP
           MOVE POUP-SALDO TO WS-DIS
           DISPLAY 'DEPOSITO REALIZADO! Novo saldo: R$ ' WS-DIS
           IF POUP-SALDO >= POUP-META
               DISPLAY '*** META ATINGIDA! Parabens! ***'
           END-IF
           MOVE 0 TO LS-CODIGO.

       3100-MOVIMENTAR-RAZAO.
           MOVE POUP-CONTA TO WS-BR-CONTA-E
           MOVE POUP-ID TO WS-BR-ID-E
           COMPUTE WS-BR-VALOR-INT-N =
               FUNCTION INTEGER-PART(WS-POUP-VALOR)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER(
                   (WS-POUP-VALOR - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPX-' POUP-ID '.OUT' DELIMITED SIZE
               INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle POUP '
                  'SAVINGS_BOX '
                  FUNCTION TRIM(WS-BR-CONTA-E) ' '
                  FUNCTION TRIM(WS-BR-VALOR-STR) ' '
                  FUNCTION TRIM(WS-BR-ID-E)
                  ' --payload "{\"action\":\"DEPOSIT\"}" '
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

       4000-RESGATAR SECTION.
       4000-INICIO.
           DISPLAY 'ID da Caixinha: '
           ACCEPT WS-POUP-ID-SEL
           MOVE WS-POUP-ID-SEL TO POUP-ID
           READ ARQPOUP KEY IS POUP-ID
           IF FS-POUP-NFD
               DISPLAY 'CAIXINHA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE POUP-SALDO TO WS-DIS
           DISPLAY 'Saldo disponivel: R$ ' WS-DIS
           DISPLAY 'Valor a resgatar (R$): '
           ACCEPT WS-POUP-VALOR
           IF WS-POUP-VALOR > POUP-SALDO
               DISPLAY 'SALDO INSUFICIENTE NA CAIXINHA'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           PERFORM 4100-RESGATAR-RAZAO
           IF WS-BR-OK NOT = 1
               DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
               MOVE 9998 TO LS-CODIGO
               EXIT SECTION
           END-IF
           SUBTRACT WS-POUP-VALOR FROM POUP-SALDO
           REWRITE REG-POUP
           DISPLAY 'RESGATE REALIZADO! Credito imediato na conta'
           MOVE 0 TO LS-CODIGO.

       4100-RESGATAR-RAZAO.
           MOVE POUP-CONTA TO WS-BR-CONTA-E
           MOVE POUP-ID TO WS-BR-ID-E
           COMPUTE WS-BR-VALOR-INT-N =
               FUNCTION INTEGER-PART(WS-POUP-VALOR)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER(
                   (WS-POUP-VALOR - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPY-' POUP-ID '.OUT' DELIMITED SIZE
               INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle POUP '
                  'SAVINGS_BOX '
                  FUNCTION TRIM(WS-BR-CONTA-E) ' '
                  FUNCTION TRIM(WS-BR-VALOR-STR) ' '
                  FUNCTION TRIM(WS-BR-ID-E)
                  ' --payload "{\"action\":\"WITHDRAW\"}" '
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

       5000-CONSULTAR SECTION.
       5000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-POUP-CONTA-NUM
           MOVE ZEROS TO WS-POUP-CTR WS-POUP-TOT-SALDO
           DISPLAY '========================================'
           DISPLAY ' CAIXINHAS DA CONTA ' WS-POUP-CONTA-NUM
           DISPLAY ' ID           Nome          Saldo      Meta'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO POUP-ID
           START ARQPOUP KEY >= POUP-ID
           PERFORM UNTIL FS-POUP-EOF
               READ ARQPOUP NEXT
               IF FS-POUP-OK
                   IF POUP-CONTA = WS-POUP-CONTA-NUM
                   AND POUP-STATUS = 'A'
                       COMPUTE WS-POUP-PERC ROUNDED =
                           POUP-SALDO * 100 / POUP-META
                       MOVE POUP-SALDO TO WS-DIS
                       DISPLAY POUP-ID ' '
                               POUP-NOME(1:14) ' R$ '
                               WS-DIS ' (' WS-POUP-PERC '% da meta)'
                       ADD 1 TO WS-POUP-CTR
                       ADD POUP-SALDO TO WS-POUP-TOT-SALDO
                   END-IF
               END-IF
           END-PERFORM
           MOVE WS-POUP-TOT-SALDO TO WS-DIS
           DISPLAY '----------------------------------------'
           DISPLAY ' Total de caixinhas: ' WS-POUP-CTR
           DISPLAY ' Total guardado: R$ ' WS-DIS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       6000-ALTERAR-META SECTION.
       6000-INICIO.
           DISPLAY 'ID da Caixinha: '
           ACCEPT WS-POUP-ID-SEL
           MOVE WS-POUP-ID-SEL TO POUP-ID
           READ ARQPOUP KEY IS POUP-ID
           IF FS-POUP-NFD
               DISPLAY 'CAIXINHA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Nova meta (R$): '
           ACCEPT POUP-META
           DISPLAY 'Novo prazo (AAAAMMDD): '
           ACCEPT POUP-DT-META
           REWRITE REG-POUP
           DISPLAY 'META ATUALIZADA COM SUCESSO'
           MOVE 0 TO LS-CODIGO.

       7000-ENCERRAR SECTION.
       7000-INICIO.
           DISPLAY 'ID da Caixinha: '
           ACCEPT WS-POUP-ID-SEL
           MOVE WS-POUP-ID-SEL TO POUP-ID
           READ ARQPOUP KEY IS POUP-ID
           IF FS-POUP-NFD
               DISPLAY 'CAIXINHA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE POUP-SALDO TO WS-DIS
           DISPLAY 'Saldo a devolver para a conta: R$ ' WS-DIS
           DISPLAY 'Confirmar encerramento? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE ZEROS TO POUP-SALDO
               MOVE 'E' TO POUP-STATUS
               REWRITE REG-POUP
               DISPLAY 'CAIXINHA ENCERRADA E SALDO DEVOLVIDO'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO ABORTADA'
           END-IF.

       9999-FIM.
           EXIT PROGRAM.
