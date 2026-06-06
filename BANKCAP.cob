      *================================================================
      * BANKCAP.COB - Titulo de Capitalizacao
      * Sistema Bancario COBOL
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKCAP.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCAP ASSIGN TO 'BANKCAP.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS CAP-NUM-TITULO
               FILE STATUS IS FS-CAP.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCAP.
       01  REG-CAP.
           05  CAP-NUM-TITULO        PIC 9(12).
           05  CAP-CONTA             PIC 9(10).
           05  CAP-TITULAR           PIC X(60).
           05  CAP-CPF               PIC X(11).
           05  CAP-SERIE             PIC X(10).
           05  CAP-VALOR-MENS        PIC S9(9)V99 COMP-3.
           05  CAP-PRAZO-MESES       PIC 9(4).
           05  CAP-MESES-PAGOS       PIC 9(4).
           05  CAP-RESERVA           PIC S9(11)V99 COMP-3.
           05  CAP-DT-INICIO         PIC 9(8).
           05  CAP-DT-VENCTO         PIC 9(8).
           05  CAP-STATUS            PIC X(1).
           05  CAP-SORTEIOS          PIC 9(4).
           05  CAP-PREMIADO          PIC X(1).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-CAP-CTRL.
           05  FS-CAP                PIC XX.
               88  FS-CAP-OK         VALUE '00'.
               88  FS-CAP-EOF        VALUE '10'.
               88  FS-CAP-NFD        VALUE '23'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CAP-PARAR         VALUE 'N'.
           05  WS-CAP-SEQ            PIC 9(12) VALUE ZEROS.

       01  WS-CAP-PLANOS.
           05  WS-CAP-PERC-RESERVA   PIC 9(3)V99 COMP-3 VALUE 70,00.
           05  WS-CAP-PERC-SORTEIO   PIC 9(3)V99 COMP-3 VALUE 25,00.
           05  WS-CAP-PERC-CARREGAM  PIC 9(3)V99 COMP-3 VALUE 5,00.

       01  WS-CAP-CALC.
           05  WS-CAP-CONTA-NUM      PIC 9(10).
           05  WS-CAP-VALOR          PIC S9(9)V99 COMP-3.
           05  WS-CAP-PRAZO          PIC 9(4).
           05  WS-CAP-RESERVA-CAL    PIC S9(11)V99 COMP-3.
           05  WS-CAP-TOTAL-CAL      PIC S9(11)V99 COMP-3.
           05  WS-CAP-ID-SEL         PIC 9(12).
           05  WS-CAP-SORTEIO-NUM    PIC 9(8).
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQCAP
           IF NOT FS-CAP-OK
               OPEN OUTPUT ARQCAP
               CLOSE ARQCAP
               OPEN I-O ARQCAP
           END-IF
           PERFORM 9900-SEQ
           PERFORM 1000-MENU UNTIL CAP-PARAR
           CLOSE ARQCAP
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-SEQ.
           MOVE 999999999999 TO CAP-NUM-TITULO
           START ARQCAP KEY <= CAP-NUM-TITULO
           READ ARQCAP PREVIOUS
           IF FS-CAP-OK
               MOVE CAP-NUM-TITULO TO WS-CAP-SEQ
           ELSE
               MOVE ZEROS TO WS-CAP-SEQ
           END-IF.

      *================================================================
       1000-MENU SECTION.
      *================================================================
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '      TITULO DE CAPITALIZACAO'
           DISPLAY '========================================'
           DISPLAY ' 01. Adquirir Titulo'
           DISPLAY ' 02. Consultar Titulos'
           DISPLAY ' 03. Pagar Mensalidade'
           DISPLAY ' 04. Participar de Sorteio'
           DISPLAY ' 05. Resgatar Titulo'
           DISPLAY ' 06. Titulos Premiados'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-ADQUIRIR
               WHEN '02' PERFORM 3000-CONSULTAR
               WHEN '03' PERFORM 4000-PAGAR-MENS
               WHEN '04' PERFORM 5000-SORTEIO
               WHEN '05' PERFORM 6000-RESGATAR
               WHEN '06' PERFORM 7000-PREMIADOS
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

      *================================================================
       2000-ADQUIRIR SECTION.
      *================================================================
       2000-INICIO.
           DISPLAY '--- ADQUIRIR TITULO ---'
           DISPLAY 'Composicao: 70% reserva, 25% sorteio,'
           DISPLAY '             5% carregamento'
           DISPLAY 'Conta para debito: '
           ACCEPT WS-CAP-CONTA-NUM
           DISPLAY 'Nome: '
           ACCEPT WS-CONTA-TITULAR
           DISPLAY 'CPF: '
           ACCEPT WS-CONTA-CPF
           DISPLAY 'Serie (MENSAL/TRIMESTRAL/ANUAL): '
           ACCEPT CAP-SERIE
           DISPLAY 'Valor mensal (R$): '
           ACCEPT WS-CAP-VALOR
           DISPLAY 'Prazo (12/24/36/48/60 meses): '
           ACCEPT WS-CAP-PRAZO
           COMPUTE WS-CAP-TOTAL-CAL =
               WS-CAP-VALOR * WS-CAP-PRAZO
           COMPUTE WS-CAP-RESERVA-CAL =
               WS-CAP-TOTAL-CAL * WS-CAP-PERC-RESERVA / 100
           MOVE WS-CAP-VALOR TO WS-DIS
           DISPLAY 'Mensalidade:         R$ ' WS-DIS
           MOVE WS-CAP-TOTAL-CAL TO WS-DIS
           DISPLAY 'Total a pagar:       R$ ' WS-DIS
           MOVE WS-CAP-RESERVA-CAL TO WS-DIS
           DISPLAY 'Reserva p/resgate:   R$ ' WS-DIS
           DISPLAY 'Sorteios: mensais durante vigencia'
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               ADD 1 TO WS-CAP-SEQ
               MOVE WS-CAP-SEQ TO CAP-NUM-TITULO
               MOVE WS-CAP-SEQ TO WS-CAP-ID-SEL
               MOVE WS-CAP-CONTA-NUM TO CAP-CONTA
               MOVE WS-CONTA-TITULAR TO CAP-TITULAR
               MOVE WS-CONTA-CPF TO CAP-CPF
               MOVE WS-CAP-VALOR TO CAP-VALOR-MENS
               MOVE WS-CAP-PRAZO TO CAP-PRAZO-MESES
               MOVE ZEROS TO CAP-MESES-PAGOS CAP-SORTEIOS
               MOVE ZEROS TO CAP-RESERVA
               MOVE FUNCTION CURRENT-DATE(1:8) TO CAP-DT-INICIO
               MOVE 'A' TO CAP-STATUS
               MOVE 'N' TO CAP-PREMIADO
               WRITE REG-CAP
               IF FS-CAP-OK
                   DISPLAY 'TITULO EMITIDO! No.: ' CAP-NUM-TITULO
                   MOVE 0 TO LS-CODIGO
               ELSE
                   DISPLAY 'ERRO: ' FS-CAP
                   MOVE 9999 TO LS-CODIGO
               END-IF
           ELSE
               DISPLAY 'CANCELADO'
           END-IF.

      *================================================================
       3000-CONSULTAR SECTION.
      *================================================================
       3000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-CAP-CONTA-NUM
           DISPLAY '========================================'
           DISPLAY ' Titulo       Serie       Valor  Pago/Total St'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO CAP-NUM-TITULO
           START ARQCAP KEY >= CAP-NUM-TITULO
           PERFORM UNTIL FS-CAP-EOF
               READ ARQCAP NEXT
               IF FS-CAP-OK
                   IF CAP-CONTA = WS-CAP-CONTA-NUM
                       MOVE CAP-VALOR-MENS TO WS-DIS
                       DISPLAY CAP-NUM-TITULO ' '
                               CAP-SERIE '  R$'
                               WS-DIS ' '
                               CAP-MESES-PAGOS '/'
                               CAP-PRAZO-MESES '  '
                               CAP-STATUS
                               ' Prem:' CAP-PREMIADO
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       4000-PAGAR-MENS SECTION.
      *================================================================
       4000-INICIO.
           DISPLAY 'Numero do titulo: '
           ACCEPT WS-CAP-ID-SEL
           MOVE WS-CAP-ID-SEL TO CAP-NUM-TITULO
           READ ARQCAP KEY IS CAP-NUM-TITULO
           IF FS-CAP-NFD
               DISPLAY 'TITULO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE CAP-VALOR-MENS TO WS-DIS
           DISPLAY 'Mensalidade: R$ ' WS-DIS
           DISPLAY 'Confirmar pagamento? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               ADD 1 TO CAP-MESES-PAGOS
               COMPUTE CAP-RESERVA = CAP-RESERVA +
                   CAP-VALOR-MENS * WS-CAP-PERC-RESERVA / 100
               IF CAP-MESES-PAGOS >= CAP-PRAZO-MESES
                   MOVE 'V' TO CAP-STATUS
               END-IF
               REWRITE REG-CAP
               DISPLAY 'MENSALIDADE REGISTRADA!'
               MOVE CAP-RESERVA TO WS-DIS
               DISPLAY 'Reserva acumulada: R$ ' WS-DIS
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CANCELADO'
           END-IF.

      *================================================================
       5000-SORTEIO SECTION.
      *================================================================
       5000-INICIO.
           DISPLAY '--- SORTEIO ---'
           DISPLAY 'Numero do titulo: '
           ACCEPT WS-CAP-ID-SEL
           MOVE WS-CAP-ID-SEL TO CAP-NUM-TITULO
           READ ARQCAP KEY IS CAP-NUM-TITULO
           IF FS-CAP-NFD
               DISPLAY 'TITULO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           COMPUTE WS-CAP-SORTEIO-NUM = FUNCTION INTEGER(
               FUNCTION RANDOM(CAP-NUM-TITULO) * 99999999)
           ADD 1 TO CAP-SORTEIOS
           DISPLAY 'Numero do titulo: ' CAP-NUM-TITULO
           DISPLAY 'Numero sorteado:  ' WS-CAP-SORTEIO-NUM
           IF FUNCTION MOD(WS-CAP-SORTEIO-NUM, 1000) = 0
               MOVE 'S' TO CAP-PREMIADO
               REWRITE REG-CAP
               DISPLAY '*** PARABENS! TITULO CONTEMPLADO! ***'
               MOVE CAP-RESERVA TO WS-DIS
               DISPLAY 'Premio: R$ ' WS-DIS
           ELSE
               REWRITE REG-CAP
               DISPLAY 'Nao contemplado neste sorteio.'
               DISPLAY 'Continue participando!'
           END-IF
           MOVE 0 TO LS-CODIGO.

      *================================================================
       6000-RESGATAR SECTION.
      *================================================================
       6000-INICIO.
           DISPLAY 'Numero do titulo: '
           ACCEPT WS-CAP-ID-SEL
           MOVE WS-CAP-ID-SEL TO CAP-NUM-TITULO
           READ ARQCAP KEY IS CAP-NUM-TITULO
           IF FS-CAP-NFD
               DISPLAY 'TITULO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE CAP-RESERVA TO WS-DIS
           DISPLAY 'Reserva disponivel: R$ ' WS-DIS
           IF CAP-STATUS NOT = 'V'
               DISPLAY 'ATENCAO: resgate antecipado perde'
               DISPLAY '         parte da reserva (carregamento)'
           END-IF
           DISPLAY 'Confirmar resgate? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'R' TO CAP-STATUS
               REWRITE REG-CAP
               DISPLAY 'RESGATE REALIZADO! Credito em 1 dia util'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CANCELADO'
           END-IF.

      *================================================================
       7000-PREMIADOS SECTION.
      *================================================================
       7000-INICIO.
           DISPLAY '========================================'
           DISPLAY ' TITULOS PREMIADOS'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO CAP-NUM-TITULO
           START ARQCAP KEY >= CAP-NUM-TITULO
           PERFORM UNTIL FS-CAP-EOF
               READ ARQCAP NEXT
               IF FS-CAP-OK AND CAP-PREMIADO = 'S'
                   MOVE CAP-RESERVA TO WS-DIS
                   DISPLAY CAP-NUM-TITULO ' '
                           CAP-TITULAR(1:30) '  R$ ' WS-DIS
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
