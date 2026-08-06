       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKFGTS.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQFGTS ASSIGN TO 'BANKFGTS.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS FGTS-ID
               FILE STATUS IS FS-FGTS.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQFGTS.
       01  REG-FGTS.
           05  FGTS-ID               PIC 9(12).
           05  FGTS-CONTA            PIC 9(10).
           05  FGTS-CPF              PIC X(11).
           05  FGTS-TITULAR          PIC X(60).
           05  FGTS-EMPREGADOR       PIC X(60).
           05  FGTS-CNPJ             PIC X(14).
           05  FGTS-SALDO            PIC S9(13)V99 COMP-3.
           05  FGTS-MODALIDADE       PIC X(12).
           05  FGTS-DT-ANIVERSARIO   PIC 9(4).
           05  FGTS-DT-ADMISSAO      PIC 9(8).
           05  FGTS-STATUS           PIC X(1).
           05  FGTS-SAQUES-EXTRA     PIC 9(4).

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-FGTS-CTRL.
           05  FS-FGTS               PIC XX.
               88  FS-FGTS-OK        VALUE '00'.
               88  FS-FGTS-EOF       VALUE '10'.
               88  FS-FGTS-NFD       VALUE '23'.
           05  FS-BRIDGE             PIC XX.
               88  FS-BRIDGE-OK      VALUE '00'.
               88  FS-BRIDGE-EOF     VALUE '10'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  FGTS-PARAR        VALUE 'N'.
           05  WS-FGTS-SEQ           PIC 9(12) VALUE ZEROS.

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

       01  WS-FGTS-CALC.
           05  WS-FGTS-CONTA-NUM     PIC 9(10).
           05  WS-FGTS-ID-SEL        PIC 9(12).
           05  WS-FGTS-PERC          PIC 9(3)V99 COMP-3.
           05  WS-FGTS-SAQUE         PIC S9(11)V99 COMP-3.
           05  WS-FGTS-PARCELAS      PIC 9(3).
           05  WS-FGTS-PARC-VAL      PIC S9(9)V99 COMP-3.
           05  WS-FGTS-ANTECIP       PIC S9(11)V99 COMP-3.
           05  WS-FGTS-TAXA-MES      PIC 9(3)V9(4) COMP-3 VALUE 1,8900.
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQFGTS
           IF NOT FS-FGTS-OK
               OPEN OUTPUT ARQFGTS
               CLOSE ARQFGTS
               OPEN I-O ARQFGTS
           END-IF
           PERFORM 9900-SEQ
           PERFORM 1000-MENU UNTIL FGTS-PARAR
           CLOSE ARQFGTS
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-SEQ.
           MOVE 999999999999 TO FGTS-ID
           START ARQFGTS KEY <= FGTS-ID
           READ ARQFGTS PREVIOUS
           IF FS-FGTS-OK
               MOVE FGTS-ID TO WS-FGTS-SEQ
           ELSE
               MOVE ZEROS TO WS-FGTS-SEQ
           END-IF.

       1000-MENU SECTION.
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '    FGTS - FUNDO DE GARANTIA'
           DISPLAY '========================================'
           DISPLAY ' 01. Vincular Conta FGTS'
           DISPLAY ' 02. Consultar Saldo FGTS'
           DISPLAY ' 03. Saque-Aniversario'
           DISPLAY ' 04. Antecipar FGTS (credito)'
           DISPLAY ' 05. Simular Antecipacao'
           DISPLAY ' 06. Extrato de Movimentacoes'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-VINCULAR
               WHEN '02' PERFORM 3000-CONSULTAR-SALDO
               WHEN '03' PERFORM 4000-SAQUE-ANIVERSARIO
               WHEN '04' PERFORM 5000-ANTECIPAR
               WHEN '05' PERFORM 6000-SIMULAR
               WHEN '06' PERFORM 7000-EXTRATO
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-VINCULAR SECTION.
       2000-INICIO.
           DISPLAY '--- VINCULAR CONTA FGTS ---'
           DISPLAY 'Conta bancaria: '
           ACCEPT WS-FGTS-CONTA-NUM
           DISPLAY 'CPF do trabalhador: '
           ACCEPT WS-CONTA-CPF
           DISPLAY 'Nome: '
           ACCEPT WS-CONTA-TITULAR
           DISPLAY 'Empregador: '
           ACCEPT FGTS-EMPREGADOR
           DISPLAY 'CNPJ do empregador: '
           ACCEPT FGTS-CNPJ
           DISPLAY 'Data de admissao (AAAAMMDD): '
           ACCEPT FGTS-DT-ADMISSAO
           DISPLAY 'Saldo atual no FGTS (R$): '
           ACCEPT FGTS-SALDO
           DISPLAY 'Modalidade (RESCISAO/ANIVERSARIO): '
           ACCEPT FGTS-MODALIDADE
           DISPLAY 'Mes aniversario (01-12): '
           ACCEPT FGTS-DT-ANIVERSARIO
           ADD 1 TO WS-FGTS-SEQ
           MOVE WS-FGTS-SEQ TO FGTS-ID
           MOVE WS-FGTS-CONTA-NUM TO FGTS-CONTA
           MOVE WS-CONTA-CPF TO FGTS-CPF
           MOVE WS-CONTA-TITULAR TO FGTS-TITULAR
           MOVE 'A' TO FGTS-STATUS
           MOVE ZEROS TO FGTS-SAQUES-EXTRA
           WRITE REG-FGTS
           IF FS-FGTS-OK
               DISPLAY 'FGTS VINCULADO! ID: ' FGTS-ID
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO: ' FS-FGTS
               MOVE 9999 TO LS-CODIGO
           END-IF.

       3000-CONSULTAR-SALDO SECTION.
       3000-INICIO.
           DISPLAY 'ID FGTS ou Conta: '
           ACCEPT WS-FGTS-ID-SEL
           MOVE WS-FGTS-ID-SEL TO FGTS-ID
           READ ARQFGTS KEY IS FGTS-ID
           IF FS-FGTS-NFD
               DISPLAY 'REGISTRO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE FGTS-SALDO TO WS-DIS
           DISPLAY '========================================'
           DISPLAY ' Titular: ' FGTS-TITULAR(1:40)
           DISPLAY ' CPF: ' FGTS-CPF
           DISPLAY ' Empregador: ' FGTS-EMPREGADOR(1:30)
           DISPLAY ' Modalidade: ' FGTS-MODALIDADE
           DISPLAY ' Saldo FGTS: R$ ' WS-DIS
           DISPLAY ' Mes aniversario: ' FGTS-DT-ANIVERSARIO
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       4000-SAQUE-ANIVERSARIO SECTION.
       4000-INICIO.
           DISPLAY 'ID FGTS: '
           ACCEPT WS-FGTS-ID-SEL
           MOVE WS-FGTS-ID-SEL TO FGTS-ID
           READ ARQFGTS KEY IS FGTS-ID
           IF FS-FGTS-NFD
               DISPLAY 'REGISTRO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF FGTS-MODALIDADE NOT = 'ANIVERSARIO'
               DISPLAY 'CONTA NAO OPTANTE PELA MODALIDADE ANIVERSARIO'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           EVALUATE TRUE
               WHEN FGTS-SALDO <= 500,00
                   MOVE 50,00 TO WS-FGTS-PERC
               WHEN FGTS-SALDO <= 1000,00
                   MOVE 40,00 TO WS-FGTS-PERC
               WHEN FGTS-SALDO <= 5000,00
                   MOVE 30,00 TO WS-FGTS-PERC
               WHEN FGTS-SALDO <= 10000,00
                   MOVE 20,00 TO WS-FGTS-PERC
               WHEN OTHER
                   MOVE 15,00 TO WS-FGTS-PERC
           END-EVALUATE
           COMPUTE WS-FGTS-SAQUE ROUNDED =
               FGTS-SALDO * WS-FGTS-PERC / 100
           MOVE WS-FGTS-SAQUE TO WS-DIS
           DISPLAY 'Percentual: ' WS-FGTS-PERC '%'
           DISPLAY 'Valor do saque: R$ ' WS-DIS
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               PERFORM 4100-CREDITAR-RAZAO
               IF WS-BR-OK NOT = 1
                   DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
                   MOVE 9998 TO LS-CODIGO
                   EXIT SECTION
               END-IF
               SUBTRACT WS-FGTS-SAQUE FROM FGTS-SALDO
               ADD 1 TO FGTS-SAQUES-EXTRA
               REWRITE REG-FGTS
               DISPLAY 'SAQUE CREDITADO EM CONTA COM SUCESSO'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CANCELADO'
           END-IF.

       4100-CREDITAR-RAZAO.
           MOVE FGTS-CONTA TO WS-BR-CONTA-E
           MOVE FGTS-ID TO WS-BR-ID-E
           COMPUTE WS-BR-VALOR-INT-N =
               FUNCTION INTEGER-PART(WS-FGTS-SAQUE)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER(
                   (WS-FGTS-SAQUE - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPF-' FGTS-ID '.OUT' DELIMITED SIZE
               INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle FGTS '
                  'FGTS_WITHDRAWAL '
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

       5000-ANTECIPAR SECTION.
       5000-INICIO.
           DISPLAY 'ID FGTS: '
           ACCEPT WS-FGTS-ID-SEL
           MOVE WS-FGTS-ID-SEL TO FGTS-ID
           READ ARQFGTS KEY IS FGTS-ID
           IF FS-FGTS-NFD
               DISPLAY 'NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Numero de parcelas anuais (1-10): '
           ACCEPT WS-FGTS-PARCELAS
           PERFORM 9700-CALCULAR-ANTECIP
           MOVE WS-FGTS-ANTECIP TO WS-DIS
           DISPLAY 'Valor antecipado: R$ ' WS-DIS
           MOVE WS-FGTS-PARC-VAL TO WS-DIS
           DISPLAY 'Parcela mensal: R$ ' WS-DIS
           DISPLAY 'Taxa: ' WS-FGTS-TAXA-MES '% a.m.'
           DISPLAY 'Confirmar antecipacao? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               PERFORM 5100-CREDITAR-ANTECIP-RAZAO
               IF WS-BR-OK NOT = 1
                   DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
                   MOVE 9998 TO LS-CODIGO
                   EXIT SECTION
               END-IF
               MOVE ZEROS TO FGTS-SALDO
               REWRITE REG-FGTS
               DISPLAY 'ANTECIPACAO APROVADA E CREDITADA EM CONTA!'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CANCELADO'
           END-IF.

       5100-CREDITAR-ANTECIP-RAZAO.
           MOVE FGTS-CONTA TO WS-BR-CONTA-E
           MOVE FGTS-ID TO WS-BR-ID-E
           COMPUTE WS-BR-VALOR-INT-N =
               FUNCTION INTEGER-PART(WS-FGTS-ANTECIP)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER(
                   (WS-FGTS-ANTECIP - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPFA-' FGTS-ID '.OUT' DELIMITED SIZE
               INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle FGTS '
                  'FGTS_ADVANCE '
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

       6000-SIMULAR SECTION.
       6000-INICIO.
           DISPLAY '--- SIMULACAO ANTECIPACAO FGTS ---'
           DISPLAY 'Saldo FGTS (R$): '
           ACCEPT FGTS-SALDO
           DISPLAY 'Parcelas anuais (1-10): '
           ACCEPT WS-FGTS-PARCELAS
           PERFORM 9700-CALCULAR-ANTECIP
           DISPLAY '========================================'
           MOVE FGTS-SALDO TO WS-DIS
           DISPLAY ' Saldo FGTS: R$ ' WS-DIS
           DISPLAY ' Parcelas: ' WS-FGTS-PARCELAS ' anos'
           MOVE WS-FGTS-ANTECIP TO WS-DIS
           DISPLAY ' Valor liquido liberado: R$ ' WS-DIS
           MOVE WS-FGTS-PARC-VAL TO WS-DIS
           DISPLAY ' Desconto mensal: R$ ' WS-DIS
           DISPLAY ' Taxa: ' WS-FGTS-TAXA-MES '% a.m.'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       7000-EXTRATO SECTION.
       7000-INICIO.
           DISPLAY '========================================'
           DISPLAY ' CONTAS FGTS VINCULADAS'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO FGTS-ID
           START ARQFGTS KEY >= FGTS-ID
           PERFORM UNTIL FS-FGTS-EOF
               READ ARQFGTS NEXT
               IF FS-FGTS-OK
                   MOVE FGTS-SALDO TO WS-DIS
                   DISPLAY FGTS-ID ' '
                           FGTS-TITULAR(1:20) '  R$ '
                           WS-DIS ' ' FGTS-MODALIDADE(1:10)
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       9700-CALCULAR-ANTECIP.
           EVALUATE TRUE
               WHEN FGTS-SALDO <= 500,00
                   MOVE 50,00 TO WS-FGTS-PERC
               WHEN FGTS-SALDO <= 5000,00
                   MOVE 30,00 TO WS-FGTS-PERC
               WHEN OTHER
                   MOVE 15,00 TO WS-FGTS-PERC
           END-EVALUATE
           COMPUTE WS-FGTS-ANTECIP ROUNDED =
               FGTS-SALDO * WS-FGTS-PERC / 100
               * WS-FGTS-PARCELAS
               / (1 + WS-FGTS-TAXA-MES / 100) ** 12
           COMPUTE WS-FGTS-PARC-VAL ROUNDED =
               WS-FGTS-ANTECIP / (WS-FGTS-PARCELAS * 12).

       9999-FIM.
           EXIT PROGRAM.
