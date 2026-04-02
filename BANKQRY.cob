      *===============================================================
      * BANKQRY.COB - Modulo de Consultas e Extratos
      *===============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKQRY.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS QRY-CONTA-NUM
               ALTERNATE RECORD KEY IS QRY-CONTA-CPF WITH DUPLICATES
               FILE STATUS IS FS-CONTAS.

           SELECT ARQTRANS ASSIGN TO 'BANKTRAN.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS QRY-TRANS-ID
               FILE STATUS IS FS-TRANS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONTAS.
       01  REG-CONTA.
           05  QRY-CONTA-NUM         PIC 9(10).
           05  QRY-CONTA-AGENCIA     PIC 9(4).
           05  QRY-CONTA-DIGITO      PIC 9(1).
           05  QRY-CONTA-TIPO        PIC X(2).
           05  QRY-CONTA-STATUS      PIC X(1).
           05  QRY-CONTA-SALDO       PIC S9(13)V99 COMP-3.
           05  QRY-CONTA-LIMITE      PIC S9(11)V99 COMP-3.
           05  QRY-CONTA-TITULAR     PIC X(60).
           05  QRY-CONTA-CPF         PIC X(11).
           05  QRY-CONTA-EMAIL       PIC X(80).
           05  QRY-CONTA-TELEFONE    PIC X(15).
           05  QRY-CONTA-DT-ABERTURA PIC 9(8).
           05  QRY-CONTA-DT-ATUALIZACAO PIC 9(8).
           05  QRY-CONTA-SENHA-HASH  PIC X(64).

       FD  ARQTRANS.
       01  REG-TRANS.
           05  QRY-TRANS-ID          PIC 9(15).
           05  QRY-TRANS-CONTA-ORG   PIC 9(10).
           05  QRY-TRANS-CONTA-DEST  PIC 9(10).
           05  QRY-TRANS-TIPO        PIC X(3).
           05  QRY-TRANS-VALOR       PIC S9(13)V99 COMP-3.
           05  QRY-TRANS-DATA        PIC 9(8).
           05  QRY-TRANS-HORA        PIC 9(6).
           05  QRY-TRANS-DESCRICAO   PIC X(100).
           05  QRY-TRANS-STATUS      PIC X(1).
           05  QRY-TRANS-NSU         PIC 9(12).
           05  QRY-TRANS-CANAL       PIC X(10).

       WORKING-STORAGE SECTION.
       01  WS-CTRL.
           05  FS-CONTAS             PIC XX.
               88  FS-OK             VALUE '00'.
               88  FS-EOF            VALUE '10'.
               88  FS-NFD            VALUE '23'.
           05  FS-TRANS              PIC XX.
               88  FS-OK-TRANS       VALUE '00'.
               88  FS-EOF-TRANS      VALUE '10'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CONTINUAR         VALUE 'S'.
               88  PARAR             VALUE 'N'.

       01  WS-CONSULTA.
           05  WS-CONS-CONTA         PIC 9(10).
           05  WS-CONS-CPF           PIC X(11).
           05  WS-VALOR-DISPLAY      PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-QTD-LINHAS         PIC 9(4) VALUE ZEROS.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL.
           OPEN INPUT ARQCONTAS ARQTRANS
           PERFORM 1000-MENU UNTIL PARAR
           CLOSE ARQCONTAS ARQTRANS
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU.
           DISPLAY '----------------------------------------'
           DISPLAY ' CONSULTAS E EXTRATOS'
           DISPLAY '----------------------------------------'
           DISPLAY ' 01. Consultar conta por numero'
           DISPLAY ' 02. Consultar conta por CPF'
           DISPLAY ' 03. Extrato rapido por conta'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO

           EVALUATE WS-OPCAO
               WHEN '01'
                   PERFORM 2000-CONSULTAR-NUM
               WHEN '02'
                   PERFORM 3000-CONSULTAR-CPF
               WHEN '03'
                   PERFORM 4000-EXTRATO-RAPIDO
               WHEN '00'
                   MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER
                   DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-CONSULTAR-NUM.
           DISPLAY 'Numero da conta: '
           ACCEPT WS-CONS-CONTA
           MOVE WS-CONS-CONTA TO QRY-CONTA-NUM
           READ ARQCONTAS KEY IS QRY-CONTA-NUM
           IF FS-NFD
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
           ELSE IF FS-OK
               PERFORM 2100-EXIBIR-CONTA
           ELSE
               DISPLAY 'ERRO DE LEITURA: ' FS-CONTAS
               MOVE 9999 TO LS-CODIGO
           END-IF.

       2100-EXIBIR-CONTA.
           MOVE QRY-CONTA-SALDO TO WS-VALOR-DISPLAY
           DISPLAY 'Titular: ' QRY-CONTA-TITULAR
           DISPLAY 'Conta: ' QRY-CONTA-NUM
           DISPLAY 'Agencia: ' QRY-CONTA-AGENCIA '-' QRY-CONTA-DIGITO
           DISPLAY 'CPF: ' QRY-CONTA-CPF
           DISPLAY 'Tipo: ' QRY-CONTA-TIPO
           DISPLAY 'Status: ' QRY-CONTA-STATUS
           DISPLAY 'Saldo: R$ ' WS-VALOR-DISPLAY.

       3000-CONSULTAR-CPF.
           DISPLAY 'CPF (11 digitos): '
           ACCEPT WS-CONS-CPF
           MOVE WS-CONS-CPF TO QRY-CONTA-CPF
           READ ARQCONTAS KEY IS QRY-CONTA-CPF
           IF FS-NFD
               DISPLAY 'CPF SEM CONTA CADASTRADA'
               MOVE 2 TO LS-CODIGO
           ELSE IF FS-OK
               PERFORM 2100-EXIBIR-CONTA
           ELSE
               DISPLAY 'ERRO DE LEITURA: ' FS-CONTAS
               MOVE 9999 TO LS-CODIGO
           END-IF.

       4000-EXTRATO-RAPIDO.
           DISPLAY 'Numero da conta: '
           ACCEPT WS-CONS-CONTA
           MOVE ZEROS TO WS-QTD-LINHAS
           MOVE ZEROS TO QRY-TRANS-ID
           START ARQTRANS KEY >= QRY-TRANS-ID
           PERFORM UNTIL FS-EOF-TRANS
               READ ARQTRANS NEXT
               IF NOT FS-EOF-TRANS
                   IF QRY-TRANS-CONTA-ORG = WS-CONS-CONTA
                      OR QRY-TRANS-CONTA-DEST = WS-CONS-CONTA
                       ADD 1 TO WS-QTD-LINHAS
                       MOVE QRY-TRANS-VALOR TO WS-VALOR-DISPLAY
                       DISPLAY QRY-TRANS-DATA SPACE
                               QRY-TRANS-TIPO SPACE
                               WS-VALOR-DISPLAY SPACE
                               QRY-TRANS-STATUS
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY 'Registros exibidos: ' WS-QTD-LINHAS.
