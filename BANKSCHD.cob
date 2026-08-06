       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKSCHD.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS SCHD-CONTA-NUM
               FILE STATUS IS FS-CONTAS.

           SELECT ARQAGEND ASSIGN TO 'BANKAGEND.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS AGEND-ID
               ALTERNATE RECORD KEY IS AGEND-CONTA
                   WITH DUPLICATES
               FILE STATUS IS FS-AGEND.

           SELECT ARQTRANS ASSIGN TO 'BANKTRAN.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS SCHD-TRANS-ID
               FILE STATUS IS FS-TRANS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONTAS.
       01  REG-CONTA-SCHD.
           05  SCHD-CONTA-NUM        PIC 9(10).
           05  SCHD-CONTA-AGENCIA    PIC 9(4).
           05  SCHD-CONTA-DIGITO     PIC 9(1).
           05  SCHD-CONTA-TIPO       PIC X(2).
           05  SCHD-CONTA-STATUS     PIC X(1).
           05  SCHD-CONTA-SALDO      PIC S9(13)V99 COMP-3.
           05  SCHD-CONTA-LIMITE     PIC S9(11)V99 COMP-3.
           05  SCHD-CONTA-TITULAR    PIC X(60).
           05  SCHD-CONTA-CPF        PIC X(11).
           05  SCHD-CONTA-EMAIL      PIC X(80).
           05  SCHD-CONTA-FONE       PIC X(15).
           05  SCHD-CONTA-DT-ABER    PIC 9(8).
           05  SCHD-CONTA-DT-ATUA    PIC 9(8).
           05  SCHD-CONTA-SENHA      PIC X(64).

       FD  ARQAGEND.
       01  REG-AGEND.
           05  AGEND-ID              PIC 9(10).
           05  AGEND-CONTA           PIC 9(10).
           05  AGEND-TIPO            PIC X(3).
           05  AGEND-CONTA-DEST      PIC 9(10).
           05  AGEND-VALOR           PIC S9(13)V99 COMP-3.
           05  AGEND-DT-AGEND        PIC 9(8).
           05  AGEND-DT-EXEC         PIC 9(8).
           05  AGEND-DESCRICAO       PIC X(100).
           05  AGEND-STATUS          PIC X(1).
           05  AGEND-RECORRENCIA     PIC X(1).

       FD  ARQTRANS.
       01  REG-TRANS-SCHD.
           05  SCHD-TRANS-ID         PIC 9(15).
           05  SCHD-TRANS-ORIG       PIC 9(10).
           05  SCHD-TRANS-DEST       PIC 9(10).
           05  SCHD-TRANS-TIPO       PIC X(3).
           05  SCHD-TRANS-VALOR      PIC S9(13)V99 COMP-3.
           05  SCHD-TRANS-DATA       PIC 9(8).
           05  SCHD-TRANS-HORA       PIC 9(6).
           05  SCHD-TRANS-DESCR      PIC X(100).
           05  SCHD-TRANS-STATUS     PIC X(1).
           05  SCHD-TRANS-NSU        PIC 9(12).
           05  SCHD-TRANS-CANAL      PIC X(10).

       WORKING-STORAGE SECTION.
       01  WS-CTRL.
           05  FS-CONTAS             PIC XX.
               88  FS-OK-CONTAS      VALUE '00'.
               88  FS-NFD-CONTA      VALUE '23'.
           05  FS-AGEND              PIC XX.
               88  FS-OK-AGEND       VALUE '00'.
               88  FS-EOF-AGEND      VALUE '10'.
               88  FS-NFD-AGEND      VALUE '23'.
           05  FS-TRANS              PIC XX.
               88  FS-OK-TRANS       VALUE '00'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CONTINUAR         VALUE 'S'.
               88  PARAR             VALUE 'N'.

       01  WS-DADOS.
           05  WS-CONTA-NUM          PIC 9(10).
           05  WS-CONTA-DEST         PIC 9(10).
           05  WS-CONTA-SALDO        PIC S9(13)V99 COMP-3.
           05  WS-CONTA-LIMITE       PIC S9(11)V99 COMP-3.
           05  WS-CONTA-STATUS       PIC X(1).
           05  WS-CONTA-BUF          PIC X(295).
           05  WS-TIPO-SEL           PIC X(3).
           05  WS-VALOR              PIC S9(13)V99 COMP-3.
           05  WS-DT-AGEND           PIC 9(8).
           05  WS-RECORRENCIA        PIC X(1).
           05  WS-AGEND-ID-SEL       PIC 9(10).
           05  WS-DESCRICAO          PIC X(100).

       01  WS-EXIB.
           05  WS-VAL-EXIB           PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-CTR-EXEC           PIC 9(5) VALUE ZEROS.

       01  WS-ID-CTRL.
           05  WS-ID-DT              PIC 9(8).
           05  WS-ID-HR              PIC 9(6).
           05  WS-PROXIMO-ID         PIC 9(10).
           05  WS-TRANS-ID           PIC 9(15).
           05  WS-HOJE               PIC 9(8).

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL.
           OPEN I-O ARQCONTAS ARQTRANS
           OPEN I-O ARQAGEND
           IF FS-AGEND = '35'
               OPEN OUTPUT ARQAGEND
               CLOSE ARQAGEND
               OPEN I-O ARQAGEND
           END-IF
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-ID-DT
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-HOJE
           MOVE FUNCTION CURRENT-DATE(9:6) TO WS-ID-HR
           COMPUTE WS-TRANS-ID =
               FUNCTION NUMVAL(WS-ID-DT) * 10000000 +
               FUNCTION NUMVAL(WS-ID-HR) * 10
           COMPUTE WS-PROXIMO-ID =
               FUNCTION NUMVAL(WS-ID-DT) * 100 +
               FUNCTION NUMVAL(WS-ID-HR(1:4))
           PERFORM 1000-MENU UNTIL PARAR
           CLOSE ARQCONTAS ARQTRANS ARQAGEND
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU.
           DISPLAY '----------------------------------------'
           DISPLAY ' AGENDAMENTOS'
           DISPLAY '----------------------------------------'
           DISPLAY ' 01. Agendar Transferencia (TED/DOC/PIX)'
           DISPLAY ' 02. Agendar Pagamento de Boleto'
           DISPLAY ' 03. Listar Agendamentos da Conta'
           DISPLAY ' 04. Cancelar Agendamento'
           DISPLAY ' 05. Processar Pendentes de Hoje'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01'  PERFORM 2000-AGENDAR-TRF
               WHEN '02'  PERFORM 2500-AGENDAR-PAG
               WHEN '03'  PERFORM 3000-LISTAR
               WHEN '04'  PERFORM 4000-CANCELAR
               WHEN '05'  PERFORM 5000-PROCESSAR
               WHEN '00'  MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-AGENDAR-TRF.
           DISPLAY 'Conta Origem: '
           ACCEPT WS-CONTA-NUM
           PERFORM 2100-BUSCAR-CONTA
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Tipo (TED/DOC/PIX): '
           ACCEPT WS-TIPO-SEL
           IF WS-TIPO-SEL NOT = 'TED' AND
              WS-TIPO-SEL NOT = 'DOC' AND
              WS-TIPO-SEL NOT = 'PIX'
               MOVE 'TED' TO WS-TIPO-SEL
           END-IF
           DISPLAY 'Conta Destino: '
           ACCEPT WS-CONTA-DEST
           DISPLAY 'Valor: '
           ACCEPT WS-VALOR
           IF WS-VALOR <= ZEROS
               DISPLAY 'VALOR INVALIDO'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Data agendada (AAAAMMDD): '
           ACCEPT WS-DT-AGEND
           IF WS-DT-AGEND <= WS-HOJE
               DISPLAY 'DATA DEVE SER FUTURA'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Recorrencia (U=Unica M=Mensal S=Semanal): '
           ACCEPT WS-RECORRENCIA
           IF WS-RECORRENCIA NOT = 'U' AND
              WS-RECORRENCIA NOT = 'M' AND
              WS-RECORRENCIA NOT = 'S'
               MOVE 'U' TO WS-RECORRENCIA
           END-IF
           MOVE 'Transferencia agendada' TO WS-DESCRICAO
           PERFORM 2200-GRAVAR-AGEND
           IF LS-CODIGO = 0
               DISPLAY 'AGENDAMENTO CRIADO - ID: ' WS-PROXIMO-ID
               DISPLAY 'Data: ' WS-DT-AGEND
                       ' | Recorrencia: ' WS-RECORRENCIA
           END-IF.

       2100-BUSCAR-CONTA.
           MOVE WS-CONTA-NUM TO SCHD-CONTA-NUM
           READ ARQCONTAS KEY IS SCHD-CONTA-NUM
           IF FS-NFD-CONTA
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
           ELSE
               MOVE REG-CONTA-SCHD     TO WS-CONTA-BUF
               MOVE SCHD-CONTA-SALDO   TO WS-CONTA-SALDO
               MOVE SCHD-CONTA-LIMITE  TO WS-CONTA-LIMITE
               MOVE SCHD-CONTA-STATUS  TO WS-CONTA-STATUS
               IF WS-CONTA-STATUS NOT = 'A'
                   DISPLAY 'CONTA INATIVA'
                   MOVE 4 TO LS-CODIGO
               ELSE
                   MOVE 0 TO LS-CODIGO
               END-IF
           END-IF.

       2200-GRAVAR-AGEND.
           ADD 1 TO WS-PROXIMO-ID
           MOVE WS-PROXIMO-ID    TO AGEND-ID
           MOVE WS-CONTA-NUM     TO AGEND-CONTA
           MOVE WS-TIPO-SEL      TO AGEND-TIPO
           MOVE WS-CONTA-DEST    TO AGEND-CONTA-DEST
           MOVE WS-VALOR         TO AGEND-VALOR
           MOVE WS-DT-AGEND      TO AGEND-DT-AGEND
           MOVE ZEROS            TO AGEND-DT-EXEC
           MOVE WS-DESCRICAO     TO AGEND-DESCRICAO
           MOVE 'P'              TO AGEND-STATUS
           MOVE WS-RECORRENCIA   TO AGEND-RECORRENCIA
           WRITE REG-AGEND
           IF FS-OK-AGEND
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO GRAVAR AGEND: ' FS-AGEND
               MOVE 9 TO LS-CODIGO
           END-IF.

       2500-AGENDAR-PAG.
           DISPLAY 'Conta Debitante: '
           ACCEPT WS-CONTA-NUM
           PERFORM 2100-BUSCAR-CONTA
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           MOVE 'BOL' TO WS-TIPO-SEL
           MOVE ZEROS TO WS-CONTA-DEST
           DISPLAY 'Valor do boleto: '
           ACCEPT WS-VALOR
           IF WS-VALOR <= ZEROS
               DISPLAY 'VALOR INVALIDO'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Data pagamento (AAAAMMDD): '
           ACCEPT WS-DT-AGEND
           IF WS-DT-AGEND < WS-HOJE
               DISPLAY 'DATA INVALIDA'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Descricao (beneficiario): '
           ACCEPT WS-DESCRICAO
           MOVE 'U' TO WS-RECORRENCIA
           PERFORM 2200-GRAVAR-AGEND
           IF LS-CODIGO = 0
               DISPLAY 'PAGAMENTO AGENDADO - ID: ' WS-PROXIMO-ID
               DISPLAY 'Data: ' WS-DT-AGEND
           END-IF.

       3000-LISTAR.
           DISPLAY 'Conta: '
           ACCEPT WS-CONTA-NUM
           MOVE WS-CONTA-NUM TO AGEND-CONTA
           START ARQAGEND KEY = AGEND-CONTA
           IF FS-NFD-AGEND
               DISPLAY 'NENHUM AGENDAMENTO ENCONTRADO'
               MOVE 0 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY '--- AGENDAMENTOS DA CONTA ' WS-CONTA-NUM ' ---'
           DISPLAY 'ID         | Tipo | Data Agend | Valor'
                   '            | Sta | Rec'
           DISPLAY '-----------|------|------------|------'
                   '------------|-----|----'
           PERFORM UNTIL FS-EOF-AGEND
               READ ARQAGEND NEXT
               IF FS-OK-AGEND
                   IF AGEND-CONTA = WS-CONTA-NUM
                       MOVE AGEND-VALOR TO WS-VAL-EXIB
                       DISPLAY AGEND-ID ' | '
                               AGEND-TIPO ' | '
                               AGEND-DT-AGEND ' | '
                               'R$ ' WS-VAL-EXIB ' | '
                               AGEND-STATUS ' | '
                               AGEND-RECORRENCIA
                   ELSE
                       MOVE '10' TO FS-AGEND
                   END-IF
               END-IF
           END-PERFORM
           MOVE 0 TO LS-CODIGO.

       4000-CANCELAR.
           DISPLAY 'ID do Agendamento: '
           ACCEPT WS-AGEND-ID-SEL
           MOVE WS-AGEND-ID-SEL TO AGEND-ID
           READ ARQAGEND KEY IS AGEND-ID
           IF FS-NFD-AGEND
               DISPLAY 'AGENDAMENTO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF AGEND-STATUS NOT = 'P'
               DISPLAY 'APENAS AGENDAMENTOS PENDENTES PODEM'
                       ' SER CANCELADOS (Status: ' AGEND-STATUS ')'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE 'C' TO AGEND-STATUS
           REWRITE REG-AGEND
           DISPLAY 'AGENDAMENTO CANCELADO COM SUCESSO'
           MOVE 0 TO LS-CODIGO.

       5000-PROCESSAR.
           DISPLAY 'Processando agendamentos ate ' WS-HOJE '...'
           MOVE ZEROS TO WS-CTR-EXEC
           MOVE ZEROS TO AGEND-ID
           START ARQAGEND KEY >= AGEND-ID
           PERFORM UNTIL FS-EOF-AGEND
               READ ARQAGEND NEXT
               IF FS-OK-AGEND
                   IF AGEND-STATUS = 'P' AND
                      AGEND-DT-AGEND <= WS-HOJE
                       PERFORM 5100-EXECUTAR-AGEND
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY WS-CTR-EXEC ' agendamento(s) processado(s)'
           MOVE 0 TO LS-CODIGO.

       5100-EXECUTAR-AGEND.
           MOVE AGEND-CONTA TO WS-CONTA-NUM
           PERFORM 2100-BUSCAR-CONTA
           IF LS-CODIGO NOT = 0
               DISPLAY 'FALHA CONTA ' AGEND-CONTA
                       ' - agend ' AGEND-ID
               MOVE 'F' TO AGEND-STATUS
               REWRITE REG-AGEND
               EXIT PARAGRAPH
           END-IF
           IF (WS-CONTA-SALDO + WS-CONTA-LIMITE) < AGEND-VALOR
               DISPLAY 'SALDO INSUF - agend ' AGEND-ID
               MOVE 'F' TO AGEND-STATUS
               REWRITE REG-AGEND
               EXIT PARAGRAPH
           END-IF
           MOVE WS-CONTA-BUF TO REG-CONTA-SCHD
           SUBTRACT AGEND-VALOR FROM SCHD-CONTA-SALDO
           MOVE FUNCTION CURRENT-DATE(1:8) TO SCHD-CONTA-DT-ATUA
           REWRITE REG-CONTA-SCHD
           IF NOT FS-OK-CONTAS
               MOVE 'F' TO AGEND-STATUS
               REWRITE REG-AGEND
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-TRANS-ID
           MOVE WS-TRANS-ID      TO SCHD-TRANS-ID
           MOVE AGEND-CONTA      TO SCHD-TRANS-ORIG
           MOVE AGEND-CONTA-DEST TO SCHD-TRANS-DEST
           MOVE AGEND-TIPO       TO SCHD-TRANS-TIPO
           MOVE AGEND-VALOR      TO SCHD-TRANS-VALOR
           MOVE FUNCTION CURRENT-DATE(1:8) TO SCHD-TRANS-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO SCHD-TRANS-HORA
           MOVE AGEND-DESCRICAO  TO SCHD-TRANS-DESCR
           MOVE 'E'              TO SCHD-TRANS-STATUS
           MOVE ZEROS            TO SCHD-TRANS-NSU
           MOVE 'MODSCHD'        TO SCHD-TRANS-CANAL
           WRITE REG-TRANS-SCHD
           IF NOT FS-OK-TRANS
               MOVE 'F' TO AGEND-STATUS
               REWRITE REG-AGEND
               EXIT PARAGRAPH
           END-IF
           MOVE 'E'    TO AGEND-STATUS
           MOVE WS-HOJE TO AGEND-DT-EXEC
           EVALUATE AGEND-RECORRENCIA
               WHEN 'M'
                   COMPUTE AGEND-DT-AGEND = AGEND-DT-AGEND + 100
                   MOVE 'P' TO AGEND-STATUS
               WHEN 'S'
                   COMPUTE AGEND-DT-AGEND = AGEND-DT-AGEND + 7
                   MOVE 'P' TO AGEND-STATUS
           END-EVALUATE
           REWRITE REG-AGEND
           ADD 1 TO WS-CTR-EXEC
           DISPLAY 'Executado: agend ' AGEND-ID
                   ' | ' AGEND-TIPO
                   ' | R$ ' WS-VAL-EXIB.
