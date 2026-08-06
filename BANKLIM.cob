       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKLIM.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS LIM-CONTA-NUM
               FILE STATUS IS FS-CONTAS.
           SELECT ARQLIMHIST ASSIGN TO 'BANKLIM.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS LIMH-ID
               FILE STATUS IS FS-LIMH.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONTAS.
       01  REG-CONTA.
           05  LIM-CONTA-NUM         PIC 9(10).
           05  LIM-CONTA-AGENCIA     PIC 9(4).
           05  LIM-CONTA-DIGITO      PIC 9(1).
           05  LIM-CONTA-TIPO        PIC X(2).
           05  LIM-CONTA-STATUS      PIC X(1).
           05  LIM-CONTA-SALDO       PIC S9(13)V99 COMP-3.
           05  LIM-CONTA-LIMITE      PIC S9(11)V99 COMP-3.
           05  LIM-CONTA-TITULAR     PIC X(60).
           05  LIM-CONTA-CPF         PIC X(11).
           05  LIM-CONTA-EMAIL       PIC X(80).
           05  LIM-CONTA-TEL         PIC X(15).
           05  LIM-CONTA-DT-ABER     PIC 9(8).
           05  LIM-CONTA-DT-ATUA     PIC 9(8).
           05  LIM-CONTA-SENHA       PIC X(64).

       FD  ARQLIMHIST.
       01  REG-LIMH.
           05  LIMH-ID               PIC 9(15).
           05  LIMH-CONTA            PIC 9(10).
           05  LIMH-LIMITE-ANT       PIC S9(11)V99 COMP-3.
           05  LIMH-LIMITE-NOV       PIC S9(11)V99 COMP-3.
           05  LIMH-MOTIVO           PIC X(60).
           05  LIMH-DATA             PIC 9(8).
           05  LIMH-HORA             PIC 9(6).
           05  LIMH-TIPO             PIC X(1).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-LIM-CTRL.
           05  FS-CONTAS             PIC XX.
               88  FS-CONTA-OK       VALUE '00'.
               88  FS-CONTA-EOF      VALUE '10'.
               88  FS-CONTA-NFD      VALUE '23'.
           05  FS-LIMH               PIC XX.
               88  FS-LIMH-OK        VALUE '00'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  LIM-PARAR         VALUE 'N'.
           05  WS-LIMH-SEQ           PIC 9(15) VALUE ZEROS.

       01  WS-LIM-CALC.
           05  WS-LIM-CONTA-NUM      PIC 9(10).
           05  WS-LIM-NOVO           PIC S9(11)V99 COMP-3.
           05  WS-LIM-MOTIVO         PIC X(60).
           05  WS-LIM-TIPO-HIST      PIC X(1).
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.
           05  WS-LIMH-ID-BASE       PIC 9(15).

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQCONTAS
           OPEN I-O ARQLIMHIST
           IF FS-LIMH NOT = '00'
               OPEN OUTPUT ARQLIMHIST
               CLOSE ARQLIMHIST
               OPEN I-O ARQLIMHIST
           END-IF
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-LIMH-ID-BASE
           COMPUTE WS-LIMH-ID-BASE =
               FUNCTION NUMVAL(WS-LIMH-ID-BASE) * 10000000
           PERFORM 1000-MENU UNTIL LIM-PARAR
           CLOSE ARQCONTAS ARQLIMHIST
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU SECTION.
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '      GESTAO DE LIMITES DE CREDITO'
           DISPLAY '========================================'
           DISPLAY ' 01. Consultar Limite Atual'
           DISPLAY ' 02. Solicitar Aumento de Limite'
           DISPLAY ' 03. Reduzir Limite'
           DISPLAY ' 04. Limite Emergencial (24h)'
           DISPLAY ' 05. Bloqueio Temporario de Limite'
           DISPLAY ' 06. Historico de Alteracoes'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-CONSULTAR
               WHEN '02' PERFORM 3000-SOLICITAR-AUMENTO
               WHEN '03' PERFORM 4000-REDUZIR
               WHEN '04' PERFORM 5000-EMERGENCIAL
               WHEN '05' PERFORM 6000-BLOQUEAR
               WHEN '06' PERFORM 7000-HISTORICO
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-CONSULTAR SECTION.
       2000-INICIO.
           DISPLAY 'Numero da conta: '
           ACCEPT WS-LIM-CONTA-NUM
           MOVE WS-LIM-CONTA-NUM TO LIM-CONTA-NUM
           READ ARQCONTAS KEY IS LIM-CONTA-NUM
           IF FS-CONTA-NFD
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE LIM-CONTA-LIMITE TO WS-DIS
           DISPLAY '========================================'
           DISPLAY ' Conta: ' LIM-CONTA-NUM
           DISPLAY ' Titular: ' LIM-CONTA-TITULAR(1:40)
           DISPLAY ' Tipo: ' LIM-CONTA-TIPO
           DISPLAY ' Limite atual:   R$ ' WS-DIS
           MOVE LIM-CONTA-SALDO TO WS-DIS
           DISPLAY ' Saldo:          R$ ' WS-DIS
           COMPUTE WS-LIM-NOVO =
               LIM-CONTA-SALDO + LIM-CONTA-LIMITE
           MOVE WS-LIM-NOVO TO WS-DIS
           DISPLAY ' Disponivel:     R$ ' WS-DIS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       3000-SOLICITAR-AUMENTO SECTION.
       3000-INICIO.
           DISPLAY 'Numero da conta: '
           ACCEPT WS-LIM-CONTA-NUM
           MOVE WS-LIM-CONTA-NUM TO LIM-CONTA-NUM
           READ ARQCONTAS KEY IS LIM-CONTA-NUM
           IF FS-CONTA-NFD
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE LIM-CONTA-LIMITE TO WS-DIS
           DISPLAY 'Limite atual: R$ ' WS-DIS
           DISPLAY 'Novo limite solicitado (R$): '
           ACCEPT WS-LIM-NOVO
           IF WS-LIM-NOVO <= LIM-CONTA-LIMITE
               DISPLAY 'NOVO LIMITE DEVE SER MAIOR QUE O ATUAL'
               MOVE 3 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Motivo da solicitacao: '
           ACCEPT WS-LIM-MOTIVO
           MOVE LIM-CONTA-LIMITE TO WS-DIS
           DISPLAY 'De: R$ ' WS-DIS
           MOVE WS-LIM-NOVO TO WS-DIS
           DISPLAY 'Para: R$ ' WS-DIS
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'A' TO WS-LIM-TIPO-HIST
               PERFORM 9700-GRAVAR-HIST
               MOVE WS-LIM-NOVO TO LIM-CONTA-LIMITE
               MOVE FUNCTION CURRENT-DATE(1:8) TO LIM-CONTA-DT-ATUA
               REWRITE REG-CONTA
               IF FS-CONTA-OK
                   DISPLAY 'LIMITE ATUALIZADO COM SUCESSO!'
                   MOVE 0 TO LS-CODIGO
               ELSE
                   DISPLAY 'ERRO: ' FS-CONTAS
                   MOVE 9999 TO LS-CODIGO
               END-IF
           ELSE
               DISPLAY 'SOLICITACAO CANCELADA'
           END-IF.

       4000-REDUZIR SECTION.
       4000-INICIO.
           DISPLAY 'Numero da conta: '
           ACCEPT WS-LIM-CONTA-NUM
           MOVE WS-LIM-CONTA-NUM TO LIM-CONTA-NUM
           READ ARQCONTAS KEY IS LIM-CONTA-NUM
           IF FS-CONTA-NFD
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE LIM-CONTA-LIMITE TO WS-DIS
           DISPLAY 'Limite atual: R$ ' WS-DIS
           DISPLAY 'Novo limite (menor valor): '
           ACCEPT WS-LIM-NOVO
           MOVE 'R' TO WS-LIM-TIPO-HIST
           PERFORM 9700-GRAVAR-HIST
           MOVE WS-LIM-NOVO TO LIM-CONTA-LIMITE
           MOVE FUNCTION CURRENT-DATE(1:8) TO LIM-CONTA-DT-ATUA
           REWRITE REG-CONTA
           DISPLAY 'LIMITE REDUZIDO COM SUCESSO'
           MOVE 0 TO LS-CODIGO.

       5000-EMERGENCIAL SECTION.
       5000-INICIO.
           DISPLAY '--- LIMITE EMERGENCIAL (expira em 24h) ---'
           DISPLAY 'Numero da conta: '
           ACCEPT WS-LIM-CONTA-NUM
           MOVE WS-LIM-CONTA-NUM TO LIM-CONTA-NUM
           READ ARQCONTAS KEY IS LIM-CONTA-NUM
           IF FS-CONTA-NFD
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE LIM-CONTA-LIMITE TO WS-DIS
           DISPLAY 'Limite atual: R$ ' WS-DIS
           COMPUTE WS-LIM-NOVO = LIM-CONTA-LIMITE * 1,20
           MOVE WS-LIM-NOVO TO WS-DIS
           DISPLAY 'Limite emergencial (+20%): R$ ' WS-DIS
           DISPLAY 'Valido por 24 horas. Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'EMERGENCIAL 24H' TO WS-LIM-MOTIVO
               MOVE 'E' TO WS-LIM-TIPO-HIST
               PERFORM 9700-GRAVAR-HIST
               MOVE WS-LIM-NOVO TO LIM-CONTA-LIMITE
               REWRITE REG-CONTA
               DISPLAY 'LIMITE EMERGENCIAL ATIVADO!'
               DISPLAY 'Retorna ao normal em 24 horas'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CANCELADO'
           END-IF.

       6000-BLOQUEAR SECTION.
       6000-INICIO.
           DISPLAY 'Numero da conta: '
           ACCEPT WS-LIM-CONTA-NUM
           MOVE WS-LIM-CONTA-NUM TO LIM-CONTA-NUM
           READ ARQCONTAS KEY IS LIM-CONTA-NUM
           IF FS-CONTA-NFD
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Confirmar bloqueio do limite? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'BLOQUEIO' TO WS-LIM-MOTIVO
               MOVE ZEROS TO WS-LIM-NOVO
               MOVE 'B' TO WS-LIM-TIPO-HIST
               PERFORM 9700-GRAVAR-HIST
               MOVE ZEROS TO LIM-CONTA-LIMITE
               REWRITE REG-CONTA
               DISPLAY 'LIMITE BLOQUEADO TEMPORARIAMENTE'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CANCELADO'
           END-IF.

       7000-HISTORICO SECTION.
       7000-INICIO.
           DISPLAY 'Numero da conta: '
           ACCEPT WS-LIM-CONTA-NUM
           DISPLAY '========================================'
           DISPLAY ' HISTORICO DE ALTERACOES DE LIMITE'
           DISPLAY ' Data     Tipo  Ant           Novo'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO LIMH-ID
           START ARQLIMHIST KEY >= LIMH-ID
           PERFORM UNTIL FS-LIMH NOT = '00'
               READ ARQLIMHIST NEXT
               IF FS-LIMH-OK
                   IF LIMH-CONTA = WS-LIM-CONTA-NUM
                       MOVE LIMH-LIMITE-ANT TO WS-DIS
                       DISPLAY LIMH-DATA ' '
                               LIMH-TIPO '  R$ ' WS-DIS
                       MOVE LIMH-LIMITE-NOV TO WS-DIS
                       DISPLAY '      -> R$ ' WS-DIS
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       9700-GRAVAR-HIST.
           ADD 1 TO WS-LIMH-SEQ
           MOVE WS-LIMH-SEQ TO LIMH-ID
           MOVE WS-LIM-CONTA-NUM TO LIMH-CONTA
           MOVE LIM-CONTA-LIMITE TO LIMH-LIMITE-ANT
           MOVE WS-LIM-NOVO TO LIMH-LIMITE-NOV
           MOVE WS-LIM-MOTIVO TO LIMH-MOTIVO
           MOVE FUNCTION CURRENT-DATE(1:8) TO LIMH-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO LIMH-HORA
           MOVE WS-LIM-TIPO-HIST TO LIMH-TIPO
           WRITE REG-LIMH.

       9999-FIM.
           EXIT PROGRAM.
