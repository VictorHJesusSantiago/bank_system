      *================================================================
      * BANKFX.COB - Modulo de Cambio e Moedas Estrangeiras
      * Sistema Bancario COBOL
      *================================================================
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

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-FX-CTRL.
           05  FS-FX                 PIC XX.
               88  FS-FX-OK          VALUE '00'.
               88  FS-FX-EOF         VALUE '10'.
               88  FS-FX-DUP         VALUE '22'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  FX-CONTINUAR      VALUE 'S'.
               88  FX-PARAR          VALUE 'N'.
           05  WS-FX-ID-BASE         PIC 9(15).

       01  WS-COTACOES.
           05  WS-USD-COMPRA         PIC 9(5)V9(6) COMP-3 VALUE 5,121000.
           05  WS-USD-VENDA          PIC 9(5)V9(6) COMP-3 VALUE 5,187000.
           05  WS-EUR-COMPRA         PIC 9(5)V9(6) COMP-3 VALUE 5,542000.
           05  WS-EUR-VENDA          PIC 9(5)V9(6) COMP-3 VALUE 5,625000.
           05  WS-GBP-COMPRA         PIC 9(5)V9(6) COMP-3 VALUE 6,432000.
           05  WS-GBP-VENDA          PIC 9(5)V9(6) COMP-3 VALUE 6,521000.
           05  WS-JPY-COMPRA         PIC 9(5)V9(6) COMP-3 VALUE 0,033400.
           05  WS-JPY-VENDA          PIC 9(5)V9(6) COMP-3 VALUE 0,033900.
           05  WS-ARS-COMPRA         PIC 9(5)V9(6) COMP-3 VALUE 0,005800.
           05  WS-ARS-VENDA          PIC 9(5)V9(6) COMP-3 VALUE 0,006200.
           05  WS-CHF-COMPRA         PIC 9(5)V9(6) COMP-3 VALUE 5,751000.
           05  WS-CHF-VENDA          PIC 9(5)V9(6) COMP-3 VALUE 5,840000.

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

      *================================================================
       1000-MENU SECTION.
      *================================================================
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

      *================================================================
       2000-COMPRAR-MOEDA SECTION.
      *================================================================
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
      *    IOF: 1,1% sobre compra fisica
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

      *================================================================
       3000-VENDER-MOEDA SECTION.
      *================================================================
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
      *    IOF: 0,38% sobre venda
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

      *================================================================
       4000-COTACOES SECTION.
      *================================================================
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

      *================================================================
       5000-SWIFT SECTION.
      *================================================================
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
      *    IOF: 0,38% para transferencias internacionais
           COMPUTE WS-FX-IOF ROUNDED =
               WS-FX-VALOR-BRL * 0,0038
           COMPUTE WS-FX-TOTAL = WS-FX-VALOR-BRL + WS-FX-IOF
           MOVE WS-FX-TOTAL TO WS-FX-DIS-BRL
           DISPLAY 'Total debitado (+ IOF 0,38%): R$ ' WS-FX-DIS-BRL
           DISPLAY 'Prazo liquidacao: D+2 uteis'
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'I' TO FX-OPERACAO
               PERFORM 2200-GRAVAR-OPERACAO-FX
               DISPLAY 'SWIFT ENVIADO! Protocolo: ' FX-ID
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO CANCELADA'
           END-IF.

      *================================================================
       6000-HISTORICO SECTION.
      *================================================================
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

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
