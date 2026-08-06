       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKRENEG.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQRENEG ASSIGN TO 'BANKRENEG.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS RENEG-ID
               FILE STATUS IS FS-RENEG.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQRENEG.
       01  REG-RENEG.
           05  RENEG-ID              PIC 9(12).
           05  RENEG-CONTA           PIC 9(10).
           05  RENEG-TIPO-DIVIDA     PIC X(15).
           05  RENEG-VALOR-ORIGINAL  PIC S9(11)V99 COMP-3.
           05  RENEG-DESCONTO-PERC   PIC 9(2)V99 COMP-3.
           05  RENEG-VALOR-NEGOCIADO PIC S9(11)V99 COMP-3.
           05  RENEG-PARCELAS        PIC 9(3).
           05  RENEG-VALOR-PARC      PIC S9(9)V99 COMP-3.
           05  RENEG-PARC-PAGAS      PIC 9(3).
           05  RENEG-DT-ACORDO       PIC 9(8).
           05  RENEG-STATUS          PIC X(1).

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-RENEG-CTRL.
           05  FS-RENEG              PIC XX.
               88  FS-RENEG-OK       VALUE '00'.
               88  FS-RENEG-EOF      VALUE '10'.
               88  FS-RENEG-NFD      VALUE '23'.
           05  FS-BRIDGE             PIC XX.
               88  FS-BRIDGE-OK      VALUE '00'.
               88  FS-BRIDGE-EOF     VALUE '10'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  RENEG-PARAR       VALUE 'N'.
           05  WS-RENEG-SEQ          PIC 9(12) VALUE ZEROS.

       01  WS-BRIDGE.
           05  WS-BR-OUTFILE          PIC X(40).
           05  WS-BR-CMD              PIC X(250).
           05  WS-BR-CONTA-E          PIC Z(9)9.
           05  WS-BR-ID-E             PIC Z(11)9.
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

       01  WS-RENEG-CALC.
           05  WS-RENEG-CONTA-NUM    PIC 9(10).
           05  WS-RENEG-ID-SEL       PIC 9(12).
           05  WS-RENEG-DIAS-ATRASO  PIC 9(5).
           05  WS-RENEG-TOTAL        PIC S9(11)V99 COMP-3.
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQRENEG
           IF NOT FS-RENEG-OK
               OPEN OUTPUT ARQRENEG
               CLOSE ARQRENEG
               OPEN I-O ARQRENEG
           END-IF
           PERFORM 9900-SEQ
           PERFORM 1000-MENU UNTIL RENEG-PARAR
           CLOSE ARQRENEG
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-SEQ.
           MOVE 999999999999 TO RENEG-ID
           START ARQRENEG KEY <= RENEG-ID
           READ ARQRENEG PREVIOUS
           IF FS-RENEG-OK
               MOVE RENEG-ID TO WS-RENEG-SEQ
           ELSE
               MOVE ZEROS TO WS-RENEG-SEQ
           END-IF.

       1000-MENU SECTION.
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '       RENEGOCIACAO DE DIVIDAS'
           DISPLAY '========================================'
           DISPLAY ' 01. Simular Renegociacao'
           DISPLAY ' 02. Fechar Acordo'
           DISPLAY ' 03. Consultar Acordos'
           DISPLAY ' 04. Pagar Parcela do Acordo'
           DISPLAY ' 05. Quitar Acordo a Vista'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-SIMULAR
               WHEN '02' PERFORM 3000-FECHAR-ACORDO
               WHEN '03' PERFORM 4000-CONSULTAR
               WHEN '04' PERFORM 5000-PAGAR-PARCELA
               WHEN '05' PERFORM 6000-QUITAR-VISTA
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-SIMULAR SECTION.
       2000-INICIO.
           DISPLAY '--- SIMULAR RENEGOCIACAO ---'
           DISPLAY 'Tipo da divida (CARTAO/EMPRESTIMO/CHEQUE-ESP/'
           DISPLAY '                 FINANCIAMENTO/OUTROS): '
           ACCEPT RENEG-TIPO-DIVIDA
           DISPLAY 'Valor original da divida (R$): '
           ACCEPT RENEG-VALOR-ORIGINAL
           DISPLAY 'Dias de atraso: '
           ACCEPT WS-RENEG-DIAS-ATRASO
           DISPLAY 'Numero de parcelas desejado (1-48): '
           ACCEPT RENEG-PARCELAS
           PERFORM 9700-CALCULAR-DESCONTO
           PERFORM 9710-CALCULAR-PARCELA
           DISPLAY '========================================'
           DISPLAY ' Desconto aplicavel: ' RENEG-DESCONTO-PERC '%'
           MOVE RENEG-VALOR-NEGOCIADO TO WS-DIS
           DISPLAY ' Valor negociado: R$ ' WS-DIS
           MOVE RENEG-VALOR-PARC TO WS-DIS
           DISPLAY ' Parcela (' RENEG-PARCELAS 'x): R$ ' WS-DIS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       3000-FECHAR-ACORDO SECTION.
       3000-INICIO.
           DISPLAY '--- FECHAR ACORDO DE RENEGOCIACAO ---'
           DISPLAY 'Conta: '
           ACCEPT WS-RENEG-CONTA-NUM
           DISPLAY 'Tipo da divida (CARTAO/EMPRESTIMO/CHEQUE-ESP/'
           DISPLAY '                 FINANCIAMENTO/OUTROS): '
           ACCEPT RENEG-TIPO-DIVIDA
           DISPLAY 'Valor original da divida (R$): '
           ACCEPT RENEG-VALOR-ORIGINAL
           DISPLAY 'Dias de atraso: '
           ACCEPT WS-RENEG-DIAS-ATRASO
           DISPLAY 'Numero de parcelas (1-48): '
           ACCEPT RENEG-PARCELAS
           PERFORM 9700-CALCULAR-DESCONTO
           PERFORM 9710-CALCULAR-PARCELA
           MOVE RENEG-VALOR-NEGOCIADO TO WS-DIS
           DISPLAY 'Valor negociado (desconto de '
                   RENEG-DESCONTO-PERC '%): R$ ' WS-DIS
           MOVE RENEG-VALOR-PARC TO WS-DIS
           DISPLAY 'Parcela mensal: R$ ' WS-DIS
           DISPLAY 'Confirmar fechamento do acordo? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO NOT = 'S'
               DISPLAY 'OPERACAO ABORTADA'
               EXIT SECTION
           END-IF
           ADD 1 TO WS-RENEG-SEQ
           MOVE WS-RENEG-SEQ TO RENEG-ID
           MOVE WS-RENEG-CONTA-NUM TO RENEG-CONTA
           MOVE ZEROS TO RENEG-PARC-PAGAS
           MOVE FUNCTION CURRENT-DATE(1:8) TO RENEG-DT-ACORDO
           MOVE 'A' TO RENEG-STATUS
           WRITE REG-RENEG
           IF FS-RENEG-OK
               DISPLAY 'ACORDO FECHADO COM SUCESSO! ID: ' RENEG-ID
               DISPLAY ' Primeira parcela vence em 30 dias'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO: ' FS-RENEG
               MOVE 9999 TO LS-CODIGO
           END-IF.

       4000-CONSULTAR SECTION.
       4000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-RENEG-CONTA-NUM
           DISPLAY '========================================'
           DISPLAY ' ACORDOS DE RENEGOCIACAO - CONTA '
                   WS-RENEG-CONTA-NUM
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO RENEG-ID
           START ARQRENEG KEY >= RENEG-ID
           PERFORM UNTIL FS-RENEG-EOF
               READ ARQRENEG NEXT
               IF FS-RENEG-OK
                   IF RENEG-CONTA = WS-RENEG-CONTA-NUM
                       MOVE RENEG-VALOR-NEGOCIADO TO WS-DIS
                       DISPLAY RENEG-ID ' ' RENEG-TIPO-DIVIDA
                               ' R$ ' WS-DIS
                       MOVE RENEG-VALOR-PARC TO WS-DIS
                       DISPLAY '   Parcela: R$ ' WS-DIS
                               '  Pagas: ' RENEG-PARC-PAGAS
                               '/' RENEG-PARCELAS
                               '  Status: ' RENEG-STATUS
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       5000-PAGAR-PARCELA SECTION.
       5000-INICIO.
           DISPLAY 'ID do Acordo: '
           ACCEPT WS-RENEG-ID-SEL
           MOVE WS-RENEG-ID-SEL TO RENEG-ID
           READ ARQRENEG KEY IS RENEG-ID
           IF FS-RENEG-NFD
               DISPLAY 'ACORDO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF RENEG-STATUS NOT = 'A'
               DISPLAY 'ACORDO NAO ESTA ATIVO'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF RENEG-PARC-PAGAS >= RENEG-PARCELAS
               DISPLAY 'ACORDO JA QUITADO'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE RENEG-VALOR-PARC TO WS-DIS
           DISPLAY 'Parcela ' RENEG-PARC-PAGAS '/' RENEG-PARCELAS
                   ': R$ ' WS-DIS
           DISPLAY 'Confirmar pagamento? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE RENEG-VALOR-PARC TO WS-BR-VALOR
               PERFORM 9750-DEBITAR-RAZAO
               IF WS-BR-OK NOT = 1
                   DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
                   MOVE 9998 TO LS-CODIGO
                   EXIT SECTION
               END-IF
               ADD 1 TO RENEG-PARC-PAGAS
               IF RENEG-PARC-PAGAS >= RENEG-PARCELAS
                   MOVE 'Q' TO RENEG-STATUS
                   DISPLAY 'PARCELA PAGA - ACORDO QUITADO!'
               ELSE
                   DISPLAY 'PARCELA PAGA COM SUCESSO'
               END-IF
               REWRITE REG-RENEG
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO ABORTADA'
           END-IF.

       6000-QUITAR-VISTA SECTION.
       6000-INICIO.
           DISPLAY 'ID do Acordo: '
           ACCEPT WS-RENEG-ID-SEL
           MOVE WS-RENEG-ID-SEL TO RENEG-ID
           READ ARQRENEG KEY IS RENEG-ID
           IF FS-RENEG-NFD
               DISPLAY 'ACORDO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF RENEG-STATUS NOT = 'A'
               DISPLAY 'ACORDO NAO ESTA ATIVO'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           COMPUTE WS-RENEG-TOTAL ROUNDED =
               RENEG-VALOR-PARC
               * (RENEG-PARCELAS - RENEG-PARC-PAGAS)
               * 0,90
           MOVE WS-RENEG-TOTAL TO WS-DIS
           DISPLAY 'Saldo com desconto adicional de quitacao (10%): R$ '
                   WS-DIS
           DISPLAY 'Confirmar quitacao a vista? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE WS-RENEG-TOTAL TO WS-BR-VALOR
               PERFORM 9750-DEBITAR-RAZAO
               IF WS-BR-OK NOT = 1
                   DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
                   MOVE 9998 TO LS-CODIGO
                   EXIT SECTION
               END-IF
               MOVE RENEG-PARCELAS TO RENEG-PARC-PAGAS
               MOVE 'Q' TO RENEG-STATUS
               REWRITE REG-RENEG
               DISPLAY 'ACORDO QUITADO COM SUCESSO!'
               DISPLAY 'Nome regularizado nos orgaos de protecao'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO ABORTADA'
           END-IF.

       9750-DEBITAR-RAZAO.
           MOVE RENEG-CONTA TO WS-BR-CONTA-E
           MOVE RENEG-ID TO WS-BR-ID-E
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
           STRING 'BANKTMPRN-' FUNCTION CURRENT-DATE(1:15) '.OUT'
                  DELIMITED SIZE INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle RENEG '
                  'DEBT_RENEGOTIATION '
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

       9700-CALCULAR-DESCONTO.
           EVALUATE TRUE
               WHEN WS-RENEG-DIAS-ATRASO > 360
                   MOVE 70,00 TO RENEG-DESCONTO-PERC
               WHEN WS-RENEG-DIAS-ATRASO > 180
                   MOVE 55,00 TO RENEG-DESCONTO-PERC
               WHEN WS-RENEG-DIAS-ATRASO > 90
                   MOVE 40,00 TO RENEG-DESCONTO-PERC
               WHEN WS-RENEG-DIAS-ATRASO > 30
                   MOVE 25,00 TO RENEG-DESCONTO-PERC
               WHEN OTHER
                   MOVE 10,00 TO RENEG-DESCONTO-PERC
           END-EVALUATE
           COMPUTE RENEG-VALOR-NEGOCIADO ROUNDED =
               RENEG-VALOR-ORIGINAL
               * (1 - RENEG-DESCONTO-PERC / 100).

       9710-CALCULAR-PARCELA.
           COMPUTE RENEG-VALOR-PARC ROUNDED =
               RENEG-VALOR-NEGOCIADO / RENEG-PARCELAS.

       9999-FIM.
           EXIT PROGRAM.
