      *================================================================
      * BANKCOB.COB - Cobranca Bancaria (Titulos a Receber)
      * Sistema Bancario COBOL
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKCOB.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCOB ASSIGN TO 'BANKCOB.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS COB-NOSSO-NUM
               FILE STATUS IS FS-COB.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCOB.
       01  REG-COB.
           05  COB-NOSSO-NUM         PIC 9(15).
           05  COB-CONTA-CEDENTE     PIC 9(10).
           05  COB-CEDENTE           PIC X(60).
           05  COB-SACADO            PIC X(60).
           05  COB-SACADO-CPF-CNPJ   PIC X(14).
           05  COB-VALOR             PIC S9(11)V99 COMP-3.
           05  COB-VALOR-PAGO        PIC S9(11)V99 COMP-3.
           05  COB-DT-EMISSAO        PIC 9(8).
           05  COB-DT-VENCTO         PIC 9(8).
           05  COB-DT-PAGAMENTO      PIC 9(8).
           05  COB-JUROS             PIC S9(9)V99 COMP-3.
           05  COB-MULTA             PIC S9(9)V99 COMP-3.
           05  COB-DESCONTO          PIC S9(9)V99 COMP-3.
           05  COB-STATUS            PIC X(1).
           05  COB-ESPECIE           PIC X(3).
           05  COB-INSTRUCAO         PIC X(80).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-COB-CTRL.
           05  FS-COB                PIC XX.
               88  FS-COB-OK         VALUE '00'.
               88  FS-COB-EOF        VALUE '10'.
               88  FS-COB-NFD        VALUE '23'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  COB-PARAR         VALUE 'N'.
           05  WS-COB-SEQ            PIC 9(15) VALUE ZEROS.

       01  WS-COB-CALC.
           05  WS-COB-CONTA-NUM      PIC 9(10).
           05  WS-COB-ID-SEL         PIC 9(15).
           05  WS-COB-DIAS           PIC 9(5) COMP-3.
           05  WS-COB-TOTAL          PIC S9(11)V99 COMP-3.
           05  WS-COB-CTR-LIQ        PIC 9(6) COMP-3.
           05  WS-COB-CTR-VENC       PIC 9(6) COMP-3.
           05  WS-COB-CTR-ABERTO     PIC 9(6) COMP-3.
           05  WS-COB-SOM-LIQ        PIC S9(13)V99 COMP-3.
           05  WS-COB-SOM-VENC       PIC S9(13)V99 COMP-3.
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.
           05  WS-COB-DATA-HOJE      PIC X(8).

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQCOB
           IF NOT FS-COB-OK
               OPEN OUTPUT ARQCOB
               CLOSE ARQCOB
               OPEN I-O ARQCOB
           END-IF
           PERFORM 9900-SEQ
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-COB-DATA-HOJE
           PERFORM 1000-MENU UNTIL COB-PARAR
           CLOSE ARQCOB
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-SEQ.
           MOVE 999999999999999 TO COB-NOSSO-NUM
           START ARQCOB KEY <= COB-NOSSO-NUM
           READ ARQCOB PREVIOUS
           IF FS-COB-OK
               MOVE COB-NOSSO-NUM TO WS-COB-SEQ
           ELSE
               MOVE ZEROS TO WS-COB-SEQ
           END-IF.

      *================================================================
       1000-MENU SECTION.
      *================================================================
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '       COBRANCA BANCARIA'
           DISPLAY '========================================'
           DISPLAY ' 01. Emitir Titulo de Cobranca'
           DISPLAY ' 02. Consultar Titulos'
           DISPLAY ' 03. Liquidar Titulo'
           DISPLAY ' 04. Cancelar Titulo'
           DISPLAY ' 05. Relatorio de Inadimplencia'
           DISPLAY ' 06. Prorrogar Vencimento'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-EMITIR
               WHEN '02' PERFORM 3000-CONSULTAR
               WHEN '03' PERFORM 4000-LIQUIDAR
               WHEN '04' PERFORM 5000-CANCELAR
               WHEN '05' PERFORM 6000-INADIMPLENCIA
               WHEN '06' PERFORM 7000-PRORROGAR
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

      *================================================================
       2000-EMITIR SECTION.
      *================================================================
       2000-INICIO.
           DISPLAY '--- EMITIR TITULO DE COBRANCA ---'
           DISPLAY 'Conta cedente: '
           ACCEPT WS-COB-CONTA-NUM
           DISPLAY 'Nome do cedente (credor): '
           ACCEPT COB-CEDENTE
           DISPLAY 'Nome do sacado (devedor): '
           ACCEPT COB-SACADO
           DISPLAY 'CPF/CNPJ do sacado: '
           ACCEPT COB-SACADO-CPF-CNPJ
           DISPLAY 'Especie (DM=Dup.Mer. NP=Nota Prom. RC=Recibo): '
           ACCEPT COB-ESPECIE
           DISPLAY 'Valor (R$): '
           ACCEPT COB-VALOR
           DISPLAY 'Vencimento (AAAAMMDD): '
           ACCEPT COB-DT-VENCTO
           DISPLAY 'Instrucoes (protestos/juros): '
           ACCEPT COB-INSTRUCAO
           ADD 1 TO WS-COB-SEQ
           MOVE WS-COB-SEQ TO COB-NOSSO-NUM
           MOVE WS-COB-CONTA-NUM TO COB-CONTA-CEDENTE
           MOVE FUNCTION CURRENT-DATE(1:8) TO COB-DT-EMISSAO
           MOVE ZEROS TO COB-VALOR-PAGO COB-DT-PAGAMENTO
                         COB-JUROS COB-MULTA COB-DESCONTO
           MOVE 'A' TO COB-STATUS
           WRITE REG-COB
           IF FS-COB-OK
               DISPLAY 'TITULO EMITIDO!'
               DISPLAY ' Nosso Numero: ' COB-NOSSO-NUM
               MOVE COB-VALOR TO WS-DIS
               DISPLAY ' Valor: R$ ' WS-DIS
               DISPLAY ' Vencimento: ' COB-DT-VENCTO
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO: ' FS-COB
               MOVE 9999 TO LS-CODIGO
           END-IF.

      *================================================================
       3000-CONSULTAR SECTION.
      *================================================================
       3000-INICIO.
           DISPLAY 'Conta cedente: '
           ACCEPT WS-COB-CONTA-NUM
           MOVE ZEROS TO WS-COB-CTR-LIQ WS-COB-CTR-ABERTO
                         WS-COB-SOM-LIQ WS-COB-SOM-VENC
           DISPLAY '========================================'
           DISPLAY ' TITULOS - CONTA ' WS-COB-CONTA-NUM
           DISPLAY ' Nosso-Num      Sacado           Valor   Vcto  St'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO COB-NOSSO-NUM
           START ARQCOB KEY >= COB-NOSSO-NUM
           PERFORM UNTIL FS-COB-EOF
               READ ARQCOB NEXT
               IF FS-COB-OK
                   IF COB-CONTA-CEDENTE = WS-COB-CONTA-NUM
                       MOVE COB-VALOR TO WS-DIS
                       DISPLAY COB-NOSSO-NUM ' '
                               COB-SACADO(1:16) '  R$ '
                               WS-DIS ' '
                               COB-DT-VENCTO ' '
                               COB-STATUS
                       EVALUATE COB-STATUS
                           WHEN 'L'
                               ADD 1 TO WS-COB-CTR-LIQ
                               ADD COB-VALOR-PAGO TO WS-COB-SOM-LIQ
                           WHEN 'A'
                               ADD 1 TO WS-COB-CTR-ABERTO
                               ADD COB-VALOR TO WS-COB-SOM-VENC
                       END-EVALUATE
                   END-IF
               END-IF
           END-PERFORM
           MOVE WS-COB-SOM-VENC TO WS-DIS
           DISPLAY '----------------------------------------'
           DISPLAY ' Abertos: ' WS-COB-CTR-ABERTO
                   '  A receber: R$ ' WS-DIS
           MOVE WS-COB-SOM-LIQ TO WS-DIS
           DISPLAY ' Liquidados: ' WS-COB-CTR-LIQ
                   '  Recebido: R$ ' WS-DIS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       4000-LIQUIDAR SECTION.
      *================================================================
       4000-INICIO.
           DISPLAY 'Nosso Numero: '
           ACCEPT WS-COB-ID-SEL
           MOVE WS-COB-ID-SEL TO COB-NOSSO-NUM
           READ ARQCOB KEY IS COB-NOSSO-NUM
           IF FS-COB-NFD
               DISPLAY 'TITULO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF COB-STATUS NOT = 'A'
               DISPLAY 'TITULO JA LIQUIDADO OU CANCELADO'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE COB-VALOR TO WS-DIS
           DISPLAY 'Sacado: ' COB-SACADO(1:40)
           DISPLAY 'Valor original: R$ ' WS-DIS
      *    Calcula juros (1% a.m.) e multa (2%) se vencido
           MOVE ZEROS TO COB-JUROS COB-MULTA COB-DESCONTO
           IF WS-COB-DATA-HOJE > COB-DT-VENCTO
               COMPUTE COB-MULTA ROUNDED =
                   COB-VALOR * 0,02
               COMPUTE COB-JUROS ROUNDED =
                   COB-VALOR * 0,001
               MOVE COB-MULTA TO WS-DIS
               DISPLAY 'Multa (2%): R$ ' WS-DIS
               MOVE COB-JUROS TO WS-DIS
               DISPLAY 'Juros: R$ ' WS-DIS
           END-IF
           COMPUTE WS-COB-TOTAL =
               COB-VALOR + COB-JUROS + COB-MULTA - COB-DESCONTO
           MOVE WS-COB-TOTAL TO WS-DIS
           DISPLAY 'Total a pagar: R$ ' WS-DIS
           DISPLAY 'Confirmar liquidacao? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE WS-COB-TOTAL TO COB-VALOR-PAGO
               MOVE FUNCTION CURRENT-DATE(1:8) TO COB-DT-PAGAMENTO
               MOVE 'L' TO COB-STATUS
               REWRITE REG-COB
               DISPLAY 'TITULO LIQUIDADO COM SUCESSO!'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CANCELADO'
           END-IF.

      *================================================================
       5000-CANCELAR SECTION.
      *================================================================
       5000-INICIO.
           DISPLAY 'Nosso Numero: '
           ACCEPT WS-COB-ID-SEL
           MOVE WS-COB-ID-SEL TO COB-NOSSO-NUM
           READ ARQCOB KEY IS COB-NOSSO-NUM
           IF FS-COB-NFD
               DISPLAY 'TITULO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Confirmar cancelamento? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'X' TO COB-STATUS
               REWRITE REG-COB
               DISPLAY 'TITULO CANCELADO'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO ABORTADA'
           END-IF.

      *================================================================
       6000-INADIMPLENCIA SECTION.
      *================================================================
       6000-INICIO.
           DISPLAY 'Conta cedente: '
           ACCEPT WS-COB-CONTA-NUM
           MOVE ZEROS TO WS-COB-CTR-VENC WS-COB-SOM-VENC
           DISPLAY '========================================'
           DISPLAY ' RELATORIO DE INADIMPLENCIA'
           DISPLAY ' (Titulos vencidos e nao pagos)'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO COB-NOSSO-NUM
           START ARQCOB KEY >= COB-NOSSO-NUM
           PERFORM UNTIL FS-COB-EOF
               READ ARQCOB NEXT
               IF FS-COB-OK
                   IF COB-CONTA-CEDENTE = WS-COB-CONTA-NUM
                   AND COB-STATUS = 'A'
                   AND COB-DT-VENCTO < WS-COB-DATA-HOJE
                       MOVE COB-VALOR TO WS-DIS
                       DISPLAY COB-NOSSO-NUM ' '
                               COB-SACADO(1:20) '  R$ '
                               WS-DIS ' Vcto:' COB-DT-VENCTO
                       ADD 1 TO WS-COB-CTR-VENC
                       ADD COB-VALOR TO WS-COB-SOM-VENC
                   END-IF
               END-IF
           END-PERFORM
           MOVE WS-COB-SOM-VENC TO WS-DIS
           DISPLAY '----------------------------------------'
           DISPLAY ' Total inadimplentes: ' WS-COB-CTR-VENC
           DISPLAY ' Valor total vencido: R$ ' WS-DIS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       7000-PRORROGAR SECTION.
      *================================================================
       7000-INICIO.
           DISPLAY 'Nosso Numero: '
           ACCEPT WS-COB-ID-SEL
           MOVE WS-COB-ID-SEL TO COB-NOSSO-NUM
           READ ARQCOB KEY IS COB-NOSSO-NUM
           IF FS-COB-NFD
               DISPLAY 'TITULO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Vencimento atual: ' COB-DT-VENCTO
           DISPLAY 'Novo vencimento (AAAAMMDD): '
           ACCEPT COB-DT-VENCTO
           REWRITE REG-COB
           DISPLAY 'VENCIMENTO PRORROGADO PARA: ' COB-DT-VENCTO
           MOVE 0 TO LS-CODIGO.

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
