       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKFX.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQFX ASSIGN TO 'BANKFX.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS FX-ID
               FILE STATUS IS FS-FX.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQFX.
       01  REG-FX.
           05  FX-ID                 PIC 9(15).
           05  FX-CONTA              PIC 9(10).
           05  FX-MOEDA              PIC X(3).
           05  FX-OPERACAO           PIC X(1).
           05  FX-VALOR-BRL          PIC S9(13)V99 COMP-3.
           05  FX-VALOR-MED          PIC S9(13)V9(6) COMP-3.
           05  FX-COTACAO            PIC S9(7)V9(6) COMP-3.
           05  FX-IOF                PIC S9(9)V99 COMP-3.
           05  FX-DATA               PIC 9(8).
           05  FX-HORA               PIC 9(6).

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-FX-CTRL.
           05  FS-FX                 PIC XX.
               88  FS-FX-OK          VALUE '00'.
               88  FS-FX-EOF         VALUE '10'.
               88  FS-FX-DUP         VALUE '22'.
           05  FS-BRIDGE             PIC XX.
               88  FS-BRIDGE-OK      VALUE '00'.
               88  FS-BRIDGE-EOF     VALUE '10'.

       01  WS-BRIDGE.
           05  WS-BR-OUTFILE          PIC X(40).
           05  WS-BR-CMD              PIC X(250).
           05  WS-BR-CONTA-E          PIC Z(9)9.
           05  WS-BR-KIND             PIC X(24).
           05  WS-BR-PAYLOAD          PIC X(40) VALUE SPACES.
           05  WS-BR-VALOR            PIC S9(13)V99 COMP-3.
           05  WS-BR-VALOR-INT-N      PIC 9(11).
           05  WS-BR-VALOR-INT-E      PIC Z(10)9.
           05  WS-BR-VALOR-DEC        PIC 99.
           05  WS-BR-VALOR-STR        PIC X(20).
           05  WS-BR-LINE             PIC X(200).
           05  WS-BR-KEY              PIC X(30).
           05  WS-BR-VAL              PIC X(160).
           05  WS-BR-OK               PIC 9 VALUE 0.
           05  WS-BR-ERROR            PIC X(150) VALUE SPACES.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  FX-CONTINUAR      VALUE 'S'.
               88  FX-PARAR          VALUE 'N'.
           05  WS-FX-ID-BASE         PIC 9(15).

       01  WS-COTACOES.
           05  WS-USD-COMPRA         PIC 9(5)V9(6) COMP-3 VALUE 5,121.
           05  WS-USD-VENDA          PIC 9(5)V9(6) COMP-3 VALUE 5,187.
           05  WS-EUR-COMPRA         PIC 9(5)V9(6) COMP-3 VALUE 5,542.
           05  WS-EUR-VENDA          PIC 9(5)V9(6) COMP-3 VALUE 5,625.
           05  WS-GBP-COMPRA         PIC 9(5)V9(6) COMP-3 VALUE 6,432.
           05  WS-GBP-VENDA          PIC 9(5)V9(6) COMP-3 VALUE 6,521.
           05  WS-JPY-COMPRA         PIC 9(5)V9(6) COMP-3 VALUE 0,0334.
           05  WS-JPY-VENDA          PIC 9(5)V9(6) COMP-3 VALUE 0,0339.
           05  WS-ARS-COMPRA         PIC 9(5)V9(6) COMP-3 VALUE 0,0058.
           05  WS-ARS-VENDA          PIC 9(5)V9(6) COMP-3 VALUE 0,0062.
           05  WS-CHF-COMPRA         PIC 9(5)V9(6) COMP-3 VALUE 5,751.
           05  WS-CHF-VENDA          PIC 9(5)V9(6) COMP-3 VALUE 5,84.

       01  WS-FX-CALC.
           05  WS-FX-MOEDA-SEL       PIC X(3).
           05  WS-FX-COTACAO-US      PIC S9(7)V9(6) COMP-3.
           05  WS-FX-VALOR-MED       PIC S9(13)V9(6) COMP-3.
           05  WS-FX-VALOR-BRL       PIC S9(13)V99 COMP-3.
           05  WS-FX-IOF             PIC S9(9)V99 COMP-3.
           05  WS-FX-TOTAL           PIC S9(13)V99 COMP-3.
           05  WS-FX-CONTA-NUM       PIC 9(10).
           05  WS-FX-DIS-COT         PIC ZZ.ZZZ,999999.
           05  WS-FX-DIS-BRL         PIC ZZZ.ZZZ.ZZZ,99-.
           05  WS-FX-DIS-MED         PIC ZZZ.ZZZ.ZZZ,999999-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQFX
           IF NOT FS-FX-OK
               OPEN OUTPUT ARQFX
               CLOSE ARQFX
               OPEN I-O ARQFX
           END-IF
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-FX-ID-BASE
           COMPUTE WS-FX-ID-BASE =
               FUNCTION NUMVAL(WS-FX-ID-BASE) * 1000000
           PERFORM 1000-MENU UNTIL FX-PARAR
           CLOSE ARQFX
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU SECTION.
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '         CAMBIO E MOEDAS'
           DISPLAY '========================================'
           DISPLAY ' 01. Comprar Moeda Estrangeira'
           DISPLAY ' 02. Vender Moeda Estrangeira'
           DISPLAY ' 03. Consultar Cotacoes'
           DISPLAY ' 04. Transferencia Internacional (SWIFT)'
           DISPLAY ' 05. Historico de Operacoes'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-COMPRAR-MOEDA
               WHEN '02' PERFORM 3000-VENDER-MOEDA
               WHEN '03' PERFORM 4000-COTACOES
               WHEN '04' PERFORM 5000-SWIFT
               WHEN '05' PERFORM 6000-HISTORICO
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-COMPRAR-MOEDA SECTION.
       2000-INICIO.
           DISPLAY '--- COMPRA DE MOEDA ESTRANGEIRA ---'
           DISPLAY 'Conta debito: '
           ACCEPT WS-FX-CONTA-NUM
           DISPLAY 'Moeda (USD/EUR/GBP/JPY/ARS/CHF): '
           ACCEPT WS-FX-MOEDA-SEL
           PERFORM 2100-SELECIONAR-COTACAO-VENDA
           IF LS-CODIGO NOT = 0
               EXIT SECTION
           END-IF
           DISPLAY 'Quantidade em moeda estrangeira: '
           ACCEPT WS-FX-VALOR-MED
           COMPUTE WS-FX-VALOR-BRL =
               WS-FX-VALOR-MED * WS-FX-COTACAO-US
           COMPUTE WS-FX-IOF ROUNDED =
               WS-FX-VALOR-BRL * 0,011
           COMPUTE WS-FX-TOTAL = WS-FX-VALOR-BRL + WS-FX-IOF
           MOVE WS-FX-COTACAO-US TO WS-FX-DIS-COT
           MOVE WS-FX-VALOR-BRL TO WS-FX-DIS-BRL
           MOVE WS-FX-VALOR-MED TO WS-FX-DIS-MED
           DISPLAY 'Cotacao ' WS-FX-MOEDA-SEL ': R$ ' WS-FX-DIS-COT
           DISPLAY 'Valor em moeda: ' WS-FX-DIS-MED
           DISPLAY 'Custo BRL:      R$ ' WS-FX-DIS-BRL
           MOVE WS-FX-IOF TO WS-FX-DIS-BRL
           DISPLAY 'IOF (1,1%):     R$ ' WS-FX-DIS-BRL
           MOVE WS-FX-TOTAL TO WS-FX-DIS-BRL
           DISPLAY 'Total debitado: R$ ' WS-FX-DIS-BRL
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'FX_BUY' TO WS-BR-KIND
               MOVE SPACES TO WS-BR-PAYLOAD
               MOVE WS-FX-CONTA-NUM TO WS-BR-CONTA-E
               MOVE WS-FX-TOTAL TO WS-BR-VALOR
               PERFORM 9850-MOVIMENTAR-RAZAO
               IF WS-BR-OK NOT = 1
                   DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
                   MOVE 9998 TO LS-CODIGO
                   EXIT SECTION
               END-IF
               PERFORM 2200-GRAVAR-OPERACAO-FX
               DISPLAY 'COMPRA REALIZADA COM SUCESSO!'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO CANCELADA'
           END-IF.

       2100-SELECIONAR-COTACAO-VENDA.
           MOVE 0 TO LS-CODIGO
           EVALUATE WS-FX-MOEDA-SEL
               WHEN 'USD' MOVE WS-USD-VENDA TO WS-FX-COTACAO-US
               WHEN 'EUR' MOVE WS-EUR-VENDA TO WS-FX-COTACAO-US
               WHEN 'GBP' MOVE WS-GBP-VENDA TO WS-FX-COTACAO-US
               WHEN 'JPY' MOVE WS-JPY-VENDA TO WS-FX-COTACAO-US
               WHEN 'ARS' MOVE WS-ARS-VENDA TO WS-FX-COTACAO-US
               WHEN 'CHF' MOVE WS-CHF-VENDA TO WS-FX-COTACAO-US
               WHEN OTHER
                   DISPLAY 'MOEDA NAO DISPONIVEL'
                   MOVE 1 TO LS-CODIGO
           END-EVALUATE.

       2200-GRAVAR-OPERACAO-FX.
           ADD 1 TO WS-FX-ID-BASE
           MOVE WS-FX-ID-BASE TO FX-ID
           MOVE WS-FX-CONTA-NUM TO FX-CONTA
           MOVE WS-FX-MOEDA-SEL TO FX-MOEDA
           MOVE 'C' TO FX-OPERACAO
           MOVE WS-FX-TOTAL TO FX-VALOR-BRL
           MOVE WS-FX-VALOR-MED TO FX-VALOR-MED
           MOVE WS-FX-COTACAO-US TO FX-COTACAO
           MOVE WS-FX-IOF TO FX-IOF
           MOVE FUNCTION CURRENT-DATE(1:8) TO FX-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO FX-HORA
           WRITE REG-FX
           IF NOT FS-FX-OK
               DISPLAY 'AVISO: ERRO AO GRAVAR HISTORICO FX: ' FS-FX
           END-IF.

       3000-VENDER-MOEDA SECTION.
       3000-INICIO.
           DISPLAY '--- VENDA DE MOEDA ESTRANGEIRA ---'
           DISPLAY 'Conta credito: '
           ACCEPT WS-FX-CONTA-NUM
           DISPLAY 'Moeda (USD/EUR/GBP/JPY/ARS/CHF): '
           ACCEPT WS-FX-MOEDA-SEL
           PERFORM 3100-SELECIONAR-COTACAO-COMPRA
           IF LS-CODIGO NOT = 0
               EXIT SECTION
           END-IF
           DISPLAY 'Quantidade em moeda estrangeira: '
           ACCEPT WS-FX-VALOR-MED
           COMPUTE WS-FX-VALOR-BRL =
               WS-FX-VALOR-MED * WS-FX-COTACAO-US
           COMPUTE WS-FX-IOF ROUNDED =
               WS-FX-VALOR-BRL * 0,0038
           COMPUTE WS-FX-TOTAL = WS-FX-VALOR-BRL - WS-FX-IOF
           MOVE WS-FX-COTACAO-US TO WS-FX-DIS-COT
           MOVE WS-FX-VALOR-BRL TO WS-FX-DIS-BRL
           MOVE WS-FX-VALOR-MED TO WS-FX-DIS-MED
           DISPLAY 'Cotacao ' WS-FX-MOEDA-SEL ': R$ ' WS-FX-DIS-COT
           DISPLAY 'Valor em moeda: ' WS-FX-DIS-MED
           DISPLAY 'Valor BRL:      R$ ' WS-FX-DIS-BRL
           MOVE WS-FX-IOF TO WS-FX-DIS-BRL
           DISPLAY 'IOF (0,38%):  - R$ ' WS-FX-DIS-BRL
           MOVE WS-FX-TOTAL TO WS-FX-DIS-BRL
           DISPLAY 'Total creditado:R$ ' WS-FX-DIS-BRL
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'FX_SELL' TO WS-BR-KIND
               STRING '"{\"direction\":\"CREDIT\"}"' DELIMITED SIZE
                      INTO WS-BR-PAYLOAD
               MOVE WS-FX-CONTA-NUM TO WS-BR-CONTA-E
               MOVE WS-FX-TOTAL TO WS-BR-VALOR
               PERFORM 9850-MOVIMENTAR-RAZAO
               IF WS-BR-OK NOT = 1
                   DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
                   MOVE 9998 TO LS-CODIGO
                   EXIT SECTION
               END-IF
               MOVE 'V' TO FX-OPERACAO
               PERFORM 2200-GRAVAR-OPERACAO-FX
               DISPLAY 'VENDA REALIZADA COM SUCESSO!'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO CANCELADA'
           END-IF.

       3100-SELECIONAR-COTACAO-COMPRA.
           MOVE 0 TO LS-CODIGO
           EVALUATE WS-FX-MOEDA-SEL
               WHEN 'USD' MOVE WS-USD-COMPRA TO WS-FX-COTACAO-US
               WHEN 'EUR' MOVE WS-EUR-COMPRA TO WS-FX-COTACAO-US
               WHEN 'GBP' MOVE WS-GBP-COMPRA TO WS-FX-COTACAO-US
               WHEN 'JPY' MOVE WS-JPY-COMPRA TO WS-FX-COTACAO-US
               WHEN 'ARS' MOVE WS-ARS-COMPRA TO WS-FX-COTACAO-US
               WHEN 'CHF' MOVE WS-CHF-COMPRA TO WS-FX-COTACAO-US
               WHEN OTHER
                   DISPLAY 'MOEDA NAO DISPONIVEL'
                   MOVE 1 TO LS-CODIGO
           END-EVALUATE.

       4000-COTACOES SECTION.
       4000-INICIO.
           MOVE WS-USD-COMPRA TO WS-FX-DIS-COT
           DISPLAY '========================================'
           DISPLAY ' COTACOES DO DIA - ' FUNCTION CURRENT-DATE(1:8)
           DISPLAY '========================================'
           DISPLAY ' Moeda  Compra          Venda'
           DISPLAY '----------------------------------------'
           MOVE WS-USD-COMPRA TO WS-FX-DIS-COT
           DISPLAY ' USD  ' WS-FX-DIS-COT
           MOVE WS-USD-VENDA TO WS-FX-DIS-COT
           DISPLAY '           ' WS-FX-DIS-COT
           MOVE WS-EUR-COMPRA TO WS-FX-DIS-COT
           DISPLAY ' EUR  ' WS-FX-DIS-COT
           MOVE WS-EUR-VENDA TO WS-FX-DIS-COT
           DISPLAY '           ' WS-FX-DIS-COT
           MOVE WS-GBP-COMPRA TO WS-FX-DIS-COT
           DISPLAY ' GBP  ' WS-FX-DIS-COT
           MOVE WS-GBP-VENDA TO WS-FX-DIS-COT
           DISPLAY '           ' WS-FX-DIS-COT
           MOVE WS-JPY-COMPRA TO WS-FX-DIS-COT
           DISPLAY ' JPY  ' WS-FX-DIS-COT
           MOVE WS-JPY-VENDA TO WS-FX-DIS-COT
           DISPLAY '           ' WS-FX-DIS-COT
           MOVE WS-ARS-COMPRA TO WS-FX-DIS-COT
           DISPLAY ' ARS  ' WS-FX-DIS-COT
           MOVE WS-ARS-VENDA TO WS-FX-DIS-COT
           DISPLAY '           ' WS-FX-DIS-COT
           MOVE WS-CHF-COMPRA TO WS-FX-DIS-COT
           DISPLAY ' CHF  ' WS-FX-DIS-COT
           MOVE WS-CHF-VENDA TO WS-FX-DIS-COT
           DISPLAY '           ' WS-FX-DIS-COT
           DISPLAY '========================================'
           DISPLAY ' Spread: diferenca entre compra e venda'
           DISPLAY ' IOF Compra Fisica: 1,1%'
           DISPLAY ' IOF Transferencia: 0,38%'
           DISPLAY '========================================'.

       5000-SWIFT SECTION.
       5000-INICIO.
           DISPLAY '--- TRANSFERENCIA INTERNACIONAL SWIFT ---'
           DISPLAY 'Conta debito: '
           ACCEPT WS-FX-CONTA-NUM
           DISPLAY 'Moeda destino (USD/EUR/GBP): '
           ACCEPT WS-FX-MOEDA-SEL
           PERFORM 2100-SELECIONAR-COTACAO-VENDA
           IF LS-CODIGO NOT = 0
               EXIT SECTION
           END-IF
           DISPLAY 'Valor em moeda estrangeira: '
           ACCEPT WS-FX-VALOR-MED
           DISPLAY 'Banco beneficiario (SWIFT code): '
           ACCEPT WS-OPCAO
           DISPLAY 'IBAN/Conta destino: '
           ACCEPT WS-OPCAO
           COMPUTE WS-FX-VALOR-BRL =
               WS-FX-VALOR-MED * WS-FX-COTACAO-US
           COMPUTE WS-FX-IOF ROUNDED =
               WS-FX-VALOR-BRL * 0,0038
           COMPUTE WS-FX-TOTAL = WS-FX-VALOR-BRL + WS-FX-IOF
           MOVE WS-FX-TOTAL TO WS-FX-DIS-BRL
           DISPLAY 'Total debitado (+ IOF 0,38%): R$ ' WS-FX-DIS-BRL
           DISPLAY 'Prazo liquidacao: D+2 uteis'
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'SWIFT_TRANSFER' TO WS-BR-KIND
               MOVE SPACES TO WS-BR-PAYLOAD
               MOVE WS-FX-CONTA-NUM TO WS-BR-CONTA-E
               MOVE WS-FX-TOTAL TO WS-BR-VALOR
               PERFORM 9850-MOVIMENTAR-RAZAO
               IF WS-BR-OK NOT = 1
                   DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
                   MOVE 9998 TO LS-CODIGO
                   EXIT SECTION
               END-IF
               MOVE 'I' TO FX-OPERACAO
               PERFORM 2200-GRAVAR-OPERACAO-FX
               DISPLAY 'SWIFT ENVIADO! Protocolo: ' FX-ID
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO CANCELADA'
           END-IF.

       6000-HISTORICO SECTION.
       6000-INICIO.
           DISPLAY 'Conta para consulta: '
           ACCEPT WS-FX-CONTA-NUM
           DISPLAY '========================================'
           DISPLAY ' HISTORICO DE OPERACOES FX'
           DISPLAY ' Op  Moeda  Valor MED         BRL'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO FX-ID
           START ARQFX KEY >= FX-ID
           PERFORM UNTIL FS-FX-EOF
               READ ARQFX NEXT
               IF FS-FX-OK
                   IF FX-CONTA = WS-FX-CONTA-NUM
                       MOVE FX-VALOR-MED TO WS-FX-DIS-MED
                       MOVE FX-VALOR-BRL TO WS-FX-DIS-BRL
                       DISPLAY FX-OPERACAO '  '
                               FX-MOEDA '  '
                               WS-FX-DIS-MED '  '
                               WS-FX-DIS-BRL
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       9850-MOVIMENTAR-RAZAO.
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
           STRING 'BANKTMPX-' FUNCTION CURRENT-DATE(1:15) '.OUT'
                  DELIMITED SIZE INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           IF WS-BR-PAYLOAD = SPACES
               STRING 'python3 bank_core_cli.py settle FX '
                      FUNCTION TRIM(WS-BR-KIND) ' '
                      FUNCTION TRIM(WS-BR-CONTA-E) ' '
                      FUNCTION TRIM(WS-BR-VALOR-STR) ' '
                      FUNCTION CURRENT-DATE(1:15)
                      ' --cobol-out ' FUNCTION TRIM(WS-BR-OUTFILE)
                      DELIMITED SIZE INTO WS-BR-CMD
           ELSE
               STRING 'python3 bank_core_cli.py settle FX '
                      FUNCTION TRIM(WS-BR-KIND) ' '
                      FUNCTION TRIM(WS-BR-CONTA-E) ' '
                      FUNCTION TRIM(WS-BR-VALOR-STR) ' '
                      FUNCTION CURRENT-DATE(1:15)
                      ' --payload ' FUNCTION TRIM(WS-BR-PAYLOAD)
                      ' --cobol-out ' FUNCTION TRIM(WS-BR-OUTFILE)
                      DELIMITED SIZE INTO WS-BR-CMD
           END-IF
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
