       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKCONSIG.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONSIG ASSIGN TO 'BANKCONSIG.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS CONSIG-ID
               FILE STATUS IS FS-CONSIG.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONSIG.
       01  REG-CONSIG.
           05  CONSIG-ID             PIC 9(12).
           05  CONSIG-CONTA          PIC 9(10).
           05  CONSIG-CONVENIO       PIC X(10).
           05  CONSIG-VALOR          PIC S9(11)V99 COMP-3.
           05  CONSIG-PARCELAS       PIC 9(3).
           05  CONSIG-VALOR-PARC     PIC S9(9)V99 COMP-3.
           05  CONSIG-TAXA-MES       PIC 9(3)V99 COMP-3.
           05  CONSIG-PARC-PAGAS     PIC 9(3).
           05  CONSIG-DT-CONTRATO    PIC 9(8).
           05  CONSIG-STATUS         PIC X(1).

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-CONSIG-CTRL.
           05  FS-CONSIG             PIC XX.
               88  FS-CONSIG-OK      VALUE '00'.
               88  FS-CONSIG-EOF     VALUE '10'.
               88  FS-CONSIG-NFD     VALUE '23'.
           05  FS-BRIDGE             PIC XX.
               88  FS-BRIDGE-OK      VALUE '00'.
               88  FS-BRIDGE-EOF     VALUE '10'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CONSIG-PARAR      VALUE 'N'.
           05  WS-CONSIG-SEQ         PIC 9(12) VALUE ZEROS.

       01  WS-BRIDGE.
           05  WS-BR-OUTFILE          PIC X(40).
           05  WS-BR-CMD              PIC X(250).
           05  WS-BR-CONTA-E          PIC Z(9)9.
           05  WS-BR-ID-E             PIC Z(11)9.
           05  WS-BR-KIND             PIC X(30).
           05  WS-BR-VALOR            PIC S9(11)V99 COMP-3.
           05  WS-BR-VALOR-INT-N      PIC 9(11).
           05  WS-BR-VALOR-INT-E      PIC Z(10)9.
           05  WS-BR-VALOR-DEC        PIC 99.
           05  WS-BR-VALOR-STR        PIC X(20).
           05  WS-BR-LINE             PIC X(200).
           05  WS-BR-KEY              PIC X(30).
           05  WS-BR-VAL              PIC X(160).
           05  WS-BR-OK               PIC 9 VALUE 0.
           05  WS-BR-ERROR            PIC X(150) VALUE SPACES.

       01  WS-CONSIG-CALC.
           05  WS-CONSIG-CONTA-NUM   PIC 9(10).
           05  WS-CONSIG-ID-SEL      PIC 9(12).
           05  WS-CONSIG-RENDA       PIC S9(11)V99 COMP-3.
           05  WS-CONSIG-MARGEM      PIC S9(11)V99 COMP-3.
           05  WS-CONSIG-TOTAL       PIC S9(13)V99 COMP-3.
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQCONSIG
           IF NOT FS-CONSIG-OK
               OPEN OUTPUT ARQCONSIG
               CLOSE ARQCONSIG
               OPEN I-O ARQCONSIG
           END-IF
           PERFORM 9900-SEQ
           PERFORM 1000-MENU UNTIL CONSIG-PARAR
           CLOSE ARQCONSIG
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-SEQ.
           MOVE 999999999999 TO CONSIG-ID
           START ARQCONSIG KEY <= CONSIG-ID
           READ ARQCONSIG PREVIOUS
           IF FS-CONSIG-OK
               MOVE CONSIG-ID TO WS-CONSIG-SEQ
           ELSE
               MOVE ZEROS TO WS-CONSIG-SEQ
           END-IF.

       1000-MENU SECTION.
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '       CREDITO CONSIGNADO'
           DISPLAY '========================================'
           DISPLAY ' 01. Consultar Margem Consignavel'
           DISPLAY ' 02. Simular Consignado'
           DISPLAY ' 03. Contratar Consignado'
           DISPLAY ' 04. Consultar Contratos'
           DISPLAY ' 05. Pagar Parcela'
           DISPLAY ' 06. Quitacao Antecipada'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-MARGEM
               WHEN '02' PERFORM 3000-SIMULAR
               WHEN '03' PERFORM 4000-CONTRATAR
               WHEN '04' PERFORM 5000-CONSULTAR
               WHEN '05' PERFORM 6000-PAGAR-PARCELA
               WHEN '06' PERFORM 7000-QUITAR
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-MARGEM SECTION.
       2000-INICIO.
           DISPLAY '--- MARGEM CONSIGNAVEL ---'
           DISPLAY 'Renda mensal / beneficio (R$): '
           ACCEPT WS-CONSIG-RENDA
           COMPUTE WS-CONSIG-MARGEM ROUNDED =
               WS-CONSIG-RENDA * 0,30
           MOVE WS-CONSIG-MARGEM TO WS-DIS
           DISPLAY '========================================'
           DISPLAY ' Margem consignavel disponivel (30%):'
           DISPLAY ' R$ ' WS-DIS ' por mes'
           DISPLAY ' (Limite legal total: ate 35% da renda)'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       3000-SIMULAR SECTION.
       3000-INICIO.
           DISPLAY '--- SIMULAR CONSIGNADO ---'
           DISPLAY 'Convenio (INSS/SERVIDOR/CLT/MILITAR): '
           ACCEPT CONSIG-CONVENIO
           DISPLAY 'Valor solicitado (R$): '
           ACCEPT CONSIG-VALOR
           DISPLAY 'Numero de parcelas (6-96): '
           ACCEPT CONSIG-PARCELAS
           EVALUATE CONSIG-CONVENIO
               WHEN 'INSS'     MOVE 1,80 TO CONSIG-TAXA-MES
               WHEN 'SERVIDOR' MOVE 1,60 TO CONSIG-TAXA-MES
               WHEN 'MILITAR'  MOVE 1,55 TO CONSIG-TAXA-MES
               WHEN OTHER      MOVE 2,30 TO CONSIG-TAXA-MES
           END-EVALUATE
           PERFORM 9700-CALCULAR-PARCELA
           DISPLAY '========================================'
           DISPLAY ' Taxa: ' CONSIG-TAXA-MES '% a.m.'
           MOVE CONSIG-VALOR-PARC TO WS-DIS
           DISPLAY ' Valor da parcela: R$ ' WS-DIS
           COMPUTE WS-CONSIG-TOTAL =
               CONSIG-VALOR-PARC * CONSIG-PARCELAS
           MOVE WS-CONSIG-TOTAL TO WS-DIS
           DISPLAY ' Total a pagar: R$ ' WS-DIS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       4000-CONTRATAR SECTION.
       4000-INICIO.
           DISPLAY '--- CONTRATAR CONSIGNADO ---'
           DISPLAY 'Conta: '
           ACCEPT WS-CONSIG-CONTA-NUM
           DISPLAY 'Convenio (INSS/SERVIDOR/CLT/MILITAR): '
           ACCEPT CONSIG-CONVENIO
           DISPLAY 'Valor solicitado (R$): '
           ACCEPT CONSIG-VALOR
           DISPLAY 'Numero de parcelas (6-96): '
           ACCEPT CONSIG-PARCELAS
           EVALUATE CONSIG-CONVENIO
               WHEN 'INSS'     MOVE 1,80 TO CONSIG-TAXA-MES
               WHEN 'SERVIDOR' MOVE 1,60 TO CONSIG-TAXA-MES
               WHEN 'MILITAR'  MOVE 1,55 TO CONSIG-TAXA-MES
               WHEN OTHER      MOVE 2,30 TO CONSIG-TAXA-MES
           END-EVALUATE
           PERFORM 9700-CALCULAR-PARCELA
           MOVE CONSIG-VALOR-PARC TO WS-DIS
           DISPLAY 'Parcela mensal: R$ ' WS-DIS
           DISPLAY 'Confirmar contratacao? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO NOT = 'S'
               DISPLAY 'OPERACAO ABORTADA'
               EXIT SECTION
           END-IF
           ADD 1 TO WS-CONSIG-SEQ
           MOVE WS-CONSIG-SEQ TO CONSIG-ID
           MOVE WS-CONSIG-CONTA-NUM TO CONSIG-CONTA
           MOVE ZEROS TO CONSIG-PARC-PAGAS
           MOVE FUNCTION CURRENT-DATE(1:8) TO CONSIG-DT-CONTRATO
           MOVE 'A' TO CONSIG-STATUS
           MOVE 'PAYROLL_LOAN' TO WS-BR-KIND
           MOVE CONSIG-VALOR TO WS-BR-VALOR
           PERFORM 9750-MOVIMENTAR-RAZAO
           IF WS-BR-OK NOT = 1
               DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
               MOVE 9998 TO LS-CODIGO
               EXIT SECTION
           END-IF
           WRITE REG-CONSIG
           IF FS-CONSIG-OK
               DISPLAY 'CONSIGNADO CONTRATADO E CREDITADO! ID: '
                       CONSIG-ID
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO: ' FS-CONSIG
               MOVE 9999 TO LS-CODIGO
           END-IF.

       5000-CONSULTAR SECTION.
       5000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-CONSIG-CONTA-NUM
           DISPLAY '========================================'
           DISPLAY ' CONTRATOS CONSIGNADOS - CONTA '
                   WS-CONSIG-CONTA-NUM
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO CONSIG-ID
           START ARQCONSIG KEY >= CONSIG-ID
           PERFORM UNTIL FS-CONSIG-EOF
               READ ARQCONSIG NEXT
               IF FS-CONSIG-OK
                   IF CONSIG-CONTA = WS-CONSIG-CONTA-NUM
                       MOVE CONSIG-VALOR TO WS-DIS
                       DISPLAY CONSIG-ID ' ' CONSIG-CONVENIO
                               ' R$ ' WS-DIS
                       MOVE CONSIG-VALOR-PARC TO WS-DIS
                       DISPLAY '   Parcela: R$ ' WS-DIS
                               '  Pagas: ' CONSIG-PARC-PAGAS
                               '/' CONSIG-PARCELAS
                               '  Status: ' CONSIG-STATUS
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       6000-PAGAR-PARCELA SECTION.
       6000-INICIO.
           DISPLAY 'ID do Contrato: '
           ACCEPT WS-CONSIG-ID-SEL
           MOVE WS-CONSIG-ID-SEL TO CONSIG-ID
           READ ARQCONSIG KEY IS CONSIG-ID
           IF FS-CONSIG-NFD
               DISPLAY 'CONTRATO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF CONSIG-STATUS NOT = 'A'
               DISPLAY 'CONTRATO NAO ESTA ATIVO'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF CONSIG-PARC-PAGAS >= CONSIG-PARCELAS
               DISPLAY 'CONTRATO JA QUITADO'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE CONSIG-VALOR-PARC TO WS-DIS
           DISPLAY 'Parcela ' CONSIG-PARC-PAGAS '/' CONSIG-PARCELAS
                   ': R$ ' WS-DIS
           DISPLAY 'Confirmar pagamento (debito em folha)? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'PAYROLL_LOAN_INSTALLMENT' TO WS-BR-KIND
               MOVE CONSIG-VALOR-PARC TO WS-BR-VALOR
               PERFORM 9750-MOVIMENTAR-RAZAO
               IF WS-BR-OK NOT = 1
                   DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
                   MOVE 9998 TO LS-CODIGO
                   EXIT SECTION
               END-IF
               ADD 1 TO CONSIG-PARC-PAGAS
               IF CONSIG-PARC-PAGAS >= CONSIG-PARCELAS
                   MOVE 'Q' TO CONSIG-STATUS
                   DISPLAY 'PARCELA PAGA - CONTRATO QUITADO!'
               ELSE
                   DISPLAY 'PARCELA PAGA COM SUCESSO'
               END-IF
               REWRITE REG-CONSIG
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO ABORTADA'
           END-IF.

       7000-QUITAR SECTION.
       7000-INICIO.
           DISPLAY 'ID do Contrato: '
           ACCEPT WS-CONSIG-ID-SEL
           MOVE WS-CONSIG-ID-SEL TO CONSIG-ID
           READ ARQCONSIG KEY IS CONSIG-ID
           IF FS-CONSIG-NFD
               DISPLAY 'CONTRATO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF CONSIG-STATUS NOT = 'A'
               DISPLAY 'CONTRATO NAO ESTA ATIVO'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           COMPUTE WS-CONSIG-TOTAL ROUNDED =
               CONSIG-VALOR-PARC
               * (CONSIG-PARCELAS - CONSIG-PARC-PAGAS)
               * 0,92
           MOVE WS-CONSIG-TOTAL TO WS-DIS
           DISPLAY 'Saldo devedor com desconto de quitacao (8%): R$ '
                   WS-DIS
           DISPLAY 'Confirmar quitacao a vista? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'PAYROLL_LOAN_INSTALLMENT' TO WS-BR-KIND
               MOVE WS-CONSIG-TOTAL TO WS-BR-VALOR
               PERFORM 9750-MOVIMENTAR-RAZAO
               IF WS-BR-OK NOT = 1
                   DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
                   MOVE 9998 TO LS-CODIGO
                   EXIT SECTION
               END-IF
               MOVE CONSIG-PARCELAS TO CONSIG-PARC-PAGAS
               MOVE 'Q' TO CONSIG-STATUS
               REWRITE REG-CONSIG
               DISPLAY 'CONTRATO QUITADO COM SUCESSO!'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO ABORTADA'
           END-IF.

       9750-MOVIMENTAR-RAZAO.
           MOVE CONSIG-CONTA TO WS-BR-CONTA-E
           MOVE CONSIG-ID TO WS-BR-ID-E
           COMPUTE WS-BR-VALOR-INT-N =
               FUNCTION INTEGER-PART(WS-BR-VALOR)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER(
                   (WS-BR-VALOR - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPG-' FUNCTION CURRENT-DATE(1:15) '.OUT'
                  DELIMITED SIZE INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle CONSIG '
                  FUNCTION TRIM(WS-BR-KIND) ' '
                  FUNCTION TRIM(WS-BR-CONTA-E) ' '
                  FUNCTION TRIM(WS-BR-VALOR-STR) ' '
                  FUNCTION CURRENT-DATE(1:15) '-'
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

       9700-CALCULAR-PARCELA.
           COMPUTE CONSIG-VALOR-PARC ROUNDED =
               CONSIG-VALOR
               * (CONSIG-TAXA-MES / 100)
               / (1 - (1 + CONSIG-TAXA-MES / 100) **
                      (- CONSIG-PARCELAS)).

       9999-FIM.
           EXIT PROGRAM.
