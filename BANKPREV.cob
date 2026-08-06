       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKPREV.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQPREV ASSIGN TO 'BANKPREV.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS PREV-ID
               FILE STATUS IS FS-PREV.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQPREV.
       01  REG-PREV.
           05  PREV-ID               PIC 9(12).
           05  PREV-CONTA            PIC 9(10).
           05  PREV-TIPO             PIC X(4).
           05  PREV-MODALIDADE       PIC X(12).
           05  PREV-TITULAR          PIC X(60).
           05  PREV-CPF              PIC X(11).
           05  PREV-APORTE-MENS      PIC S9(11)V99 COMP-3.
           05  PREV-SALDO            PIC S9(13)V99 COMP-3.
           05  PREV-RENTAB-ACUM      PIC S9(7)V9(4) COMP-3.
           05  PREV-PERFIL           PIC X(12).
           05  PREV-DT-INICIO        PIC 9(8).
           05  PREV-IDADE-APOSENTAD  PIC 9(3).
           05  PREV-STATUS           PIC X(1).

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-PREV-CTRL.
           05  FS-PREV               PIC XX.
               88  FS-PREV-OK        VALUE '00'.
               88  FS-PREV-EOF       VALUE '10'.
               88  FS-PREV-NFD       VALUE '23'.
           05  FS-BRIDGE             PIC XX.
               88  FS-BRIDGE-OK      VALUE '00'.
               88  FS-BRIDGE-EOF     VALUE '10'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  PREV-PARAR        VALUE 'N'.
           05  WS-PREV-SEQ           PIC 9(12) VALUE ZEROS.

       01  WS-BRIDGE.
           05  WS-BR-OUTFILE          PIC X(40).
           05  WS-BR-CMD              PIC X(250).
           05  WS-BR-CONTA-E          PIC Z(9)9.
           05  WS-BR-ID-E             PIC Z(11)9.
           05  WS-BR-KIND             PIC X(20).
           05  WS-BR-VALOR-INT-N      PIC 9(11).
           05  WS-BR-VALOR-INT-E      PIC Z(10)9.
           05  WS-BR-VALOR-DEC        PIC 99.
           05  WS-BR-VALOR-STR        PIC X(20).
           05  WS-BR-LINE             PIC X(200).
           05  WS-BR-KEY              PIC X(30).
           05  WS-BR-VAL              PIC X(160).
           05  WS-BR-OK               PIC 9 VALUE 0.
           05  WS-BR-ERROR            PIC X(150) VALUE SPACES.

       01  WS-PREV-CALC.
           05  WS-PREV-CONTA-NUM     PIC 9(10).
           05  WS-PREV-TIPO-SEL      PIC X(4).
           05  WS-PREV-MOD-SEL       PIC X(12).
           05  WS-PREV-PERF-SEL      PIC X(12).
           05  WS-PREV-APORTE        PIC S9(11)V99 COMP-3.
           05  WS-PREV-EXTRA         PIC S9(11)V99 COMP-3.
           05  WS-PREV-IDADE         PIC 9(3).
           05  WS-PREV-ID-SEL        PIC 9(12).
           05  WS-PREV-PROJ-10       PIC S9(13)V99 COMP-3.
           05  WS-PREV-PROJ-20       PIC S9(13)V99 COMP-3.
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQPREV
           IF NOT FS-PREV-OK
               OPEN OUTPUT ARQPREV
               CLOSE ARQPREV
               OPEN I-O ARQPREV
           END-IF
           PERFORM 9900-SEQ
           PERFORM 1000-MENU UNTIL PREV-PARAR
           CLOSE ARQPREV
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-SEQ.
           MOVE 999999999999 TO PREV-ID
           START ARQPREV KEY <= PREV-ID
           READ ARQPREV PREVIOUS
           IF FS-PREV-OK
               MOVE PREV-ID TO WS-PREV-SEQ
           ELSE
               MOVE ZEROS TO WS-PREV-SEQ
           END-IF.

       1000-MENU SECTION.
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '      PREVIDENCIA PRIVADA'
           DISPLAY '========================================'
           DISPLAY ' 01. Contratar PGBL'
           DISPLAY ' 02. Contratar VGBL'
           DISPLAY ' 03. Aporte Extraordinario'
           DISPLAY ' 04. Portabilidade entre planos'
           DISPLAY ' 05. Resgatar'
           DISPLAY ' 06. Extrato e Projecao'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01'
                   MOVE 'PGBL' TO WS-PREV-TIPO-SEL
                   PERFORM 2000-CONTRATAR
               WHEN '02'
                   MOVE 'VGBL' TO WS-PREV-TIPO-SEL
                   PERFORM 2000-CONTRATAR
               WHEN '03' PERFORM 3000-APORTE-EXTRA
               WHEN '04' PERFORM 4000-PORTABILIDADE
               WHEN '05' PERFORM 5000-RESGATAR
               WHEN '06' PERFORM 6000-EXTRATO
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-CONTRATAR SECTION.
       2000-INICIO.
           DISPLAY '--- CONTRATACAO ' WS-PREV-TIPO-SEL ' ---'
           IF WS-PREV-TIPO-SEL = 'PGBL'
               DISPLAY 'PGBL: deducao IR ate 12% renda bruta'
               DISPLAY 'Indicado para quem faz declaracao completa'
           ELSE
               DISPLAY 'VGBL: isencao IR sobre rendimentos'
               DISPLAY 'Indicado para declaracao simplificada'
           END-IF
           DISPLAY 'Conta para debito: '
           ACCEPT WS-PREV-CONTA-NUM
           DISPLAY 'Nome do titular: '
           ACCEPT WS-CONTA-TITULAR
           DISPLAY 'CPF: '
           ACCEPT WS-CONTA-CPF
           DISPLAY 'Aporte mensal (R$): '
           ACCEPT WS-PREV-APORTE
           DISPLAY 'Perfil (CONSERVADOR/MODERADO/ARROJADO): '
           ACCEPT WS-PREV-PERF-SEL
           DISPLAY 'Modalidade (PROGRESSIVO/REGRESSIVO): '
           ACCEPT WS-PREV-MOD-SEL
           DISPLAY 'Idade alvo de aposentadoria: '
           ACCEPT WS-PREV-IDADE
           MOVE WS-PREV-APORTE TO WS-DIS
           DISPLAY 'Aporte mensal: R$ ' WS-DIS
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               PERFORM 9800-GRAVAR
               DISPLAY 'PLANO CONTRATADO! ID: ' WS-PREV-ID-SEL
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CANCELADO'
           END-IF.

       3000-APORTE-EXTRA SECTION.
       3000-INICIO.
           DISPLAY 'ID do plano: '
           ACCEPT WS-PREV-ID-SEL
           MOVE WS-PREV-ID-SEL TO PREV-ID
           READ ARQPREV KEY IS PREV-ID
           IF FS-PREV-NFD
               DISPLAY 'PLANO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Valor do aporte extra: '
           ACCEPT WS-PREV-EXTRA
           MOVE 'PENSION_CONTRIBUTION' TO WS-BR-KIND
           PERFORM 9850-MOVIMENTAR-RAZAO
           IF WS-BR-OK NOT = 1
               DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
               MOVE 9998 TO LS-CODIGO
               EXIT SECTION
           END-IF
           ADD WS-PREV-EXTRA TO PREV-SALDO
           REWRITE REG-PREV
           MOVE WS-PREV-EXTRA TO WS-DIS
           DISPLAY 'APORTE DE R$ ' WS-DIS ' REALIZADO!'
           MOVE PREV-SALDO TO WS-DIS
           DISPLAY 'Saldo atual: R$ ' WS-DIS
           MOVE 0 TO LS-CODIGO.

       4000-PORTABILIDADE SECTION.
       4000-INICIO.
           DISPLAY '--- PORTABILIDADE ---'
           DISPLAY 'ID do plano origem: '
           ACCEPT WS-PREV-ID-SEL
           MOVE WS-PREV-ID-SEL TO PREV-ID
           READ ARQPREV KEY IS PREV-ID
           IF FS-PREV-NFD
               DISPLAY 'PLANO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Plano atual: ' PREV-TIPO ' / Saldo: '
           MOVE PREV-SALDO TO WS-DIS
           DISPLAY 'R$ ' WS-DIS
           DISPLAY 'Novo tipo (PGBL/VGBL): '
           ACCEPT WS-PREV-TIPO-SEL
           MOVE WS-PREV-TIPO-SEL TO PREV-TIPO
           DISPLAY 'Novo perfil (CONSERVADOR/MODERADO/ARROJADO): '
           ACCEPT WS-PREV-PERF-SEL
           MOVE WS-PREV-PERF-SEL TO PREV-PERFIL
           REWRITE REG-PREV
           DISPLAY 'PORTABILIDADE REALIZADA! Prazo: D+5 uteis'
           MOVE 0 TO LS-CODIGO.

       5000-RESGATAR SECTION.
       5000-INICIO.
           DISPLAY 'ID do plano: '
           ACCEPT WS-PREV-ID-SEL
           MOVE WS-PREV-ID-SEL TO PREV-ID
           READ ARQPREV KEY IS PREV-ID
           IF FS-PREV-NFD
               DISPLAY 'PLANO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE PREV-SALDO TO WS-DIS
           DISPLAY 'Saldo: R$ ' WS-DIS
           DISPLAY 'ATENCAO: Resgate antecipado sujeito a IR'
           DISPLAY 'Tipo resgate (P=Parcial T=Total): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'T'
               MOVE PREV-SALDO TO WS-PREV-EXTRA
           ELSE
               DISPLAY 'Valor a resgatar: '
               ACCEPT WS-PREV-EXTRA
           END-IF
           MOVE 'PENSION_REDEMPTION' TO WS-BR-KIND
           PERFORM 9850-MOVIMENTAR-RAZAO
           IF WS-BR-OK NOT = 1
               DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
               MOVE 9998 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF WS-OPCAO = 'T'
               MOVE ZEROS TO PREV-SALDO
               MOVE 'E' TO PREV-STATUS
           ELSE
               SUBTRACT WS-PREV-EXTRA FROM PREV-SALDO
           END-IF
           REWRITE REG-PREV
           DISPLAY 'RESGATE SOLICITADO! Prazo: D+4 uteis'
           MOVE 0 TO LS-CODIGO.

       9850-MOVIMENTAR-RAZAO.
           MOVE PREV-CONTA TO WS-BR-CONTA-E
           MOVE PREV-ID TO WS-BR-ID-E
           COMPUTE WS-BR-VALOR-INT-N =
               FUNCTION INTEGER-PART(WS-PREV-EXTRA)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER(
                   (WS-PREV-EXTRA - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPR-' FUNCTION CURRENT-DATE(1:15) '.OUT'
                  DELIMITED SIZE INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle PREV '
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

       6000-EXTRATO SECTION.
       6000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-PREV-CONTA-NUM
           DISPLAY '========================================'
           DISPLAY ' PLANOS DE PREVIDENCIA'
           DISPLAY ' ID            Tipo  Saldo           Perfil'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO PREV-ID
           START ARQPREV KEY >= PREV-ID
           PERFORM UNTIL FS-PREV-EOF
               READ ARQPREV NEXT
               IF FS-PREV-OK
                   IF PREV-CONTA = WS-PREV-CONTA-NUM
                       MOVE PREV-SALDO TO WS-DIS
                       DISPLAY PREV-ID ' '
                               PREV-TIPO '  R$ '
                               WS-DIS '  '
                               PREV-PERFIL(1:10)
                       COMPUTE WS-PREV-PROJ-10 =
                           PREV-SALDO * 1,08 ** 10 +
                           PREV-APORTE-MENS * 12 *
                           ((1,08 ** 10 - 1) / 0,08)
                       MOVE WS-PREV-PROJ-10 TO WS-DIS
                       DISPLAY ' Projecao 10 anos (8%aa): R$ ' WS-DIS
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       9800-GRAVAR.
           ADD 1 TO WS-PREV-SEQ
           MOVE WS-PREV-SEQ TO PREV-ID
           MOVE WS-PREV-SEQ TO WS-PREV-ID-SEL
           MOVE WS-PREV-CONTA-NUM TO PREV-CONTA
           MOVE WS-PREV-TIPO-SEL TO PREV-TIPO
           MOVE WS-PREV-MOD-SEL TO PREV-MODALIDADE
           MOVE WS-CONTA-TITULAR TO PREV-TITULAR
           MOVE WS-CONTA-CPF TO PREV-CPF
           MOVE WS-PREV-APORTE TO PREV-APORTE-MENS
           MOVE ZEROS TO PREV-SALDO PREV-RENTAB-ACUM
           MOVE WS-PREV-PERF-SEL TO PREV-PERFIL
           MOVE FUNCTION CURRENT-DATE(1:8) TO PREV-DT-INICIO
           MOVE WS-PREV-IDADE TO PREV-IDADE-APOSENTAD
           MOVE 'A' TO PREV-STATUS
           WRITE REG-PREV
           IF NOT FS-PREV-OK
               DISPLAY 'ERRO AO GRAVAR: ' FS-PREV
               MOVE 9999 TO LS-CODIGO
           END-IF.

       9999-FIM.
           EXIT PROGRAM.
