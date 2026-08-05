       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKCHQ.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCHQ ASSIGN TO 'BANKCHQ.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS CHQ-NUMERO
               FILE STATUS IS FS-CHQ.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCHQ.
       01  REG-CHQ.
           05  CHQ-NUMERO            PIC 9(10).
           05  CHQ-CONTA             PIC 9(10).
           05  CHQ-BENEFICIARIO      PIC X(60).
           05  CHQ-VALOR             PIC S9(11)V99 COMP-3.
           05  CHQ-DT-EMISSAO        PIC 9(8).
           05  CHQ-DT-COMPENSACAO    PIC 9(8).
           05  CHQ-STATUS            PIC X(1).
           05  CHQ-MOTIVO-DEV        PIC X(40).
           05  CHQ-BANCO-DESTINO     PIC 9(3).

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-CHQ-CTRL.
           05  FS-CHQ                PIC XX.
               88  FS-CHQ-OK         VALUE '00'.
               88  FS-CHQ-EOF        VALUE '10'.
               88  FS-CHQ-NFD        VALUE '23'.
               88  FS-CHQ-DUP        VALUE '22'.
           05  FS-BRIDGE             PIC XX.
               88  FS-BRIDGE-OK      VALUE '00'.
               88  FS-BRIDGE-EOF     VALUE '10'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CHQ-PARAR         VALUE 'N'.
           05  WS-CHQ-SEQ            PIC 9(10) VALUE ZEROS.

       01  WS-BRIDGE.
           05  WS-BR-OUTFILE          PIC X(40).
           05  WS-BR-CMD              PIC X(250).
           05  WS-BR-CONTA-E          PIC Z(9)9.
           05  WS-BR-ID-E             PIC Z(9)9.
           05  WS-BR-VALOR-INT-N      PIC 9(11).
           05  WS-BR-VALOR-INT-E      PIC Z(10)9.
           05  WS-BR-VALOR-DEC        PIC 99.
           05  WS-BR-VALOR-STR        PIC X(20).
           05  WS-BR-LINE             PIC X(200).
           05  WS-BR-KEY              PIC X(30).
           05  WS-BR-VAL              PIC X(160).
           05  WS-BR-OK               PIC 9 VALUE 0.
           05  WS-BR-ERROR            PIC X(150) VALUE SPACES.

       01  WS-CHQ-TALAO.
           05  WS-CHQ-CONTA-NUM      PIC 9(10).
           05  WS-CHQ-SERIE-INI      PIC 9(10).
           05  WS-CHQ-QTDE           PIC 9(3).
           05  WS-CHQ-NUM-SEL        PIC 9(10).
           05  WS-CHQ-CTR-COMP       PIC 9(6) COMP-3.
           05  WS-CHQ-CTR-PEND       PIC 9(6) COMP-3.
           05  WS-CHQ-CTR-DEV2       PIC 9(6) COMP-3.
           05  WS-CHQ-TOT-COMP       PIC S9(13)V99 COMP-3.
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQCHQ
           IF NOT FS-CHQ-OK
               OPEN OUTPUT ARQCHQ
               CLOSE ARQCHQ
               OPEN I-O ARQCHQ
           END-IF
           PERFORM 9900-SEQ
           PERFORM 1000-MENU UNTIL CHQ-PARAR
           CLOSE ARQCHQ
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-SEQ.
           MOVE 9999999999 TO CHQ-NUMERO
           START ARQCHQ KEY <= CHQ-NUMERO
           READ ARQCHQ PREVIOUS
           IF FS-CHQ-OK
               MOVE CHQ-NUMERO TO WS-CHQ-SEQ
           ELSE
               MOVE 100000 TO WS-CHQ-SEQ
           END-IF.

       1000-MENU SECTION.
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '         TALAO DE CHEQUES'
           DISPLAY '========================================'
           DISPLAY ' 01. Solicitar Novo Talao'
           DISPLAY ' 02. Emitir Cheque'
           DISPLAY ' 03. Cancelar/Sustar Cheque'
           DISPLAY ' 04. Consultar Cheques da Conta'
           DISPLAY ' 05. Verificar Compensacao'
           DISPLAY ' 06. Cheques Devolvidos (CCF)'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-SOLICITAR-TALAO
               WHEN '02' PERFORM 3000-EMITIR-CHEQUE
               WHEN '03' PERFORM 4000-SUSTAR
               WHEN '04' PERFORM 5000-CONSULTAR
               WHEN '05' PERFORM 6000-COMPENSAR
               WHEN '06' PERFORM 7000-DEVOLVIDOS
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-SOLICITAR-TALAO SECTION.
       2000-INICIO.
           DISPLAY '--- SOLICITAR TALAO ---'
           DISPLAY 'Conta: '
           ACCEPT WS-CHQ-CONTA-NUM
           DISPLAY 'Quantidade (10/20/50): '
           ACCEPT WS-CHQ-QTDE
           IF WS-CHQ-QTDE NOT = 10
           AND WS-CHQ-QTDE NOT = 20
           AND WS-CHQ-QTDE NOT = 50
               MOVE 20 TO WS-CHQ-QTDE
               DISPLAY 'Quantidade ajustada para 20'
           END-IF
           ADD 1 TO WS-CHQ-SEQ
           MOVE WS-CHQ-SEQ TO WS-CHQ-SERIE-INI
           DISPLAY '========================================'
           DISPLAY ' Talao solicitado com sucesso!'
           DISPLAY ' Conta: ' WS-CHQ-CONTA-NUM
           DISPLAY ' Serie: ' WS-CHQ-SERIE-INI
           DISPLAY ' Quantidade: ' WS-CHQ-QTDE ' folhas'
           DISPLAY ' Prazo entrega: 5 dias uteis'
           DISPLAY ' Taxa de emissao: R$ 12,90'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       3000-EMITIR-CHEQUE SECTION.
       3000-INICIO.
           DISPLAY '--- EMITIR CHEQUE ---'
           DISPLAY 'Conta emitente: '
           ACCEPT WS-CHQ-CONTA-NUM
           ADD 1 TO WS-CHQ-SEQ
           MOVE WS-CHQ-SEQ TO CHQ-NUMERO
           DISPLAY 'Beneficiario: '
           ACCEPT CHQ-BENEFICIARIO
           DISPLAY 'Valor (R$): '
           ACCEPT CHQ-VALOR
           DISPLAY 'Banco destino (codigo): '
           ACCEPT CHQ-BANCO-DESTINO
           MOVE WS-CHQ-CONTA-NUM TO CHQ-CONTA
           MOVE FUNCTION CURRENT-DATE(1:8) TO CHQ-DT-EMISSAO
           MOVE ZEROS TO CHQ-DT-COMPENSACAO
           MOVE 'E' TO CHQ-STATUS
           MOVE SPACES TO CHQ-MOTIVO-DEV
           WRITE REG-CHQ
           IF FS-CHQ-OK
               MOVE CHQ-VALOR TO WS-DIS
               DISPLAY 'CHEQUE EMITIDO!'
               DISPLAY ' No.: ' CHQ-NUMERO
               DISPLAY ' Beneficiario: ' CHQ-BENEFICIARIO(1:40)
               DISPLAY ' Valor: R$ ' WS-DIS
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO: ' FS-CHQ
               MOVE 9999 TO LS-CODIGO
           END-IF.

       4000-SUSTAR SECTION.
       4000-INICIO.
           DISPLAY 'Numero do cheque: '
           ACCEPT WS-CHQ-NUM-SEL
           MOVE WS-CHQ-NUM-SEL TO CHQ-NUMERO
           READ ARQCHQ KEY IS CHQ-NUMERO
           IF FS-CHQ-NFD
               DISPLAY 'CHEQUE NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF CHQ-STATUS = 'C'
               DISPLAY 'CHEQUE JA COMPENSADO'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE CHQ-VALOR TO WS-DIS
           DISPLAY 'Cheque No.: ' CHQ-NUMERO
           DISPLAY 'Beneficiario: ' CHQ-BENEFICIARIO(1:40)
           DISPLAY 'Valor: R$ ' WS-DIS
           DISPLAY 'Motivo da sustacao: '
           ACCEPT CHQ-MOTIVO-DEV
           MOVE 'S' TO CHQ-STATUS
           REWRITE REG-CHQ
           DISPLAY 'CHEQUE SUSTADO COM SUCESSO'
           MOVE 0 TO LS-CODIGO.

       5000-CONSULTAR SECTION.
       5000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-CHQ-CONTA-NUM
           MOVE ZEROS TO WS-CHQ-CTR-COMP WS-CHQ-CTR-PEND
                         WS-CHQ-CTR-DEV2 WS-CHQ-TOT-COMP
           DISPLAY '========================================'
           DISPLAY ' CHEQUES DA CONTA ' WS-CHQ-CONTA-NUM
           DISPLAY ' No.       Beneficiario         Valor   St'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO CHQ-NUMERO
           START ARQCHQ KEY >= CHQ-NUMERO
           PERFORM UNTIL FS-CHQ-EOF
               READ ARQCHQ NEXT
               IF FS-CHQ-OK
                   IF CHQ-CONTA = WS-CHQ-CONTA-NUM
                       MOVE CHQ-VALOR TO WS-DIS
                       DISPLAY CHQ-NUMERO ' '
                               CHQ-BENEFICIARIO(1:20) '  R$ '
                               WS-DIS ' ' CHQ-STATUS
                       EVALUATE CHQ-STATUS
                           WHEN 'C'
                               ADD 1 TO WS-CHQ-CTR-COMP
                               ADD CHQ-VALOR TO WS-CHQ-TOT-COMP
                           WHEN 'E'
                               ADD 1 TO WS-CHQ-CTR-PEND
                           WHEN 'D'
                               ADD 1 TO WS-CHQ-CTR-DEV2
                       END-EVALUATE
                   END-IF
               END-IF
           END-PERFORM
           MOVE WS-CHQ-TOT-COMP TO WS-DIS
           DISPLAY '----------------------------------------'
           DISPLAY ' Compensados: ' WS-CHQ-CTR-COMP
                   '  Pendentes: ' WS-CHQ-CTR-PEND
                   '  Devolvidos: ' WS-CHQ-CTR-DEV2
           DISPLAY ' Total compensado: R$ ' WS-DIS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       6000-COMPENSAR SECTION.
       6000-INICIO.
           DISPLAY 'Numero do cheque: '
           ACCEPT WS-CHQ-NUM-SEL
           MOVE WS-CHQ-NUM-SEL TO CHQ-NUMERO
           READ ARQCHQ KEY IS CHQ-NUMERO
           IF FS-CHQ-NFD
               DISPLAY 'CHEQUE NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE CHQ-VALOR TO WS-DIS
           DISPLAY 'Cheque: ' CHQ-NUMERO ' / R$ ' WS-DIS
           DISPLAY 'Status atual: ' CHQ-STATUS
           IF CHQ-STATUS = 'E'
               PERFORM 6100-DEBITAR-RAZAO
               IF WS-BR-OK NOT = 1
                   DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
                   MOVE 4 TO CHQ-STATUS
                   MOVE 'Falha de compensacao no razao'
                       TO CHQ-MOTIVO-DEV
                   REWRITE REG-CHQ
                   MOVE 9998 TO LS-CODIGO
                   EXIT SECTION
               END-IF
               MOVE 'C' TO CHQ-STATUS
               MOVE FUNCTION CURRENT-DATE(1:8) TO CHQ-DT-COMPENSACAO
               REWRITE REG-CHQ
               DISPLAY 'CHEQUE COMPENSADO EM ' CHQ-DT-COMPENSACAO
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CHEQUE NAO PODE SER COMPENSADO'
               MOVE 4 TO LS-CODIGO
           END-IF.

       6100-DEBITAR-RAZAO.
           MOVE CHQ-CONTA TO WS-BR-CONTA-E
           MOVE CHQ-NUMERO TO WS-BR-ID-E
           COMPUTE WS-BR-VALOR-INT-N = FUNCTION INTEGER-PART(CHQ-VALOR)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER((CHQ-VALOR - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPH-' CHQ-NUMERO '.OUT' DELIMITED SIZE
               INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle CHQ '
                  'CHEQUE_CLEARING '
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

       7000-DEVOLVIDOS SECTION.
       7000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-CHQ-CONTA-NUM
           DISPLAY '========================================'
           DISPLAY ' CHEQUES DEVOLVIDOS (CCF)'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO CHQ-NUMERO
           START ARQCHQ KEY >= CHQ-NUMERO
           PERFORM UNTIL FS-CHQ-EOF
               READ ARQCHQ NEXT
               IF FS-CHQ-OK
                   IF CHQ-CONTA = WS-CHQ-CONTA-NUM
                   AND CHQ-STATUS = 'D'
                       MOVE CHQ-VALOR TO WS-DIS
                       DISPLAY CHQ-NUMERO ' R$ '
                               WS-DIS ' ' CHQ-DT-EMISSAO
                       DISPLAY ' Motivo: ' CHQ-MOTIVO-DEV(1:40)
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           DISPLAY ' Inclusao no CCF apos 2a devolucao'
           MOVE 0 TO LS-CODIGO.

       9999-FIM.
           EXIT PROGRAM.
