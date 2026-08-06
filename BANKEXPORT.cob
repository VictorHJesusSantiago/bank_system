       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKEXPORT.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS REG-CONTA-NUM
               FILE STATUS IS FS-CONTAS.

           SELECT ARQTRANS ASSIGN TO 'BANKTRAN.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS REG-TRANS-ID
               FILE STATUS IS FS-TRANS.

           SELECT ARQDUMPCONTAS ASSIGN TO 'BANKACCT.DUMP'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-DUMP-CONTAS.

           SELECT ARQDUMPTRANS ASSIGN TO 'BANKTRAN.DUMP'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-DUMP-TRANS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONTAS.
       01  REG-CONTA.
           05  REG-CONTA-NUM         PIC 9(10).
           05  REG-CONTA-AGENCIA     PIC 9(4).
           05  REG-CONTA-DIGITO      PIC 9(1).
           05  REG-CONTA-TIPO        PIC X(2).
           05  REG-CONTA-STATUS      PIC X(1).
           05  REG-CONTA-SALDO       PIC S9(13)V99 COMP-3.
           05  REG-CONTA-LIMITE      PIC S9(11)V99 COMP-3.
           05  REG-CONTA-TITULAR     PIC X(60).
           05  REG-CONTA-CPF         PIC X(11).
           05  REG-CONTA-EMAIL       PIC X(80).
           05  REG-CONTA-TELEFONE    PIC X(15).
           05  REG-CONTA-DT-ABERTURA PIC 9(8).
           05  REG-CONTA-DT-ATUALIZACAO PIC 9(8).
           05  REG-CONTA-SENHA-HASH  PIC X(64).

       FD  ARQTRANS.
       01  REG-TRANS.
           05  REG-TRANS-ID          PIC 9(15).
           05  REG-TRANS-CONTA-ORG   PIC 9(10).
           05  REG-TRANS-CONTA-DEST  PIC 9(10).
           05  REG-TRANS-TIPO        PIC X(3).
           05  REG-TRANS-VALOR       PIC S9(13)V99 COMP-3.
           05  REG-TRANS-DATA        PIC 9(8).
           05  REG-TRANS-HORA        PIC 9(6).
           05  REG-TRANS-DESCRICAO   PIC X(100).
           05  REG-TRANS-STATUS      PIC X(1).
           05  REG-TRANS-NSU         PIC 9(12).
           05  REG-TRANS-CANAL       PIC X(10).

       FD  ARQDUMPCONTAS.
       01  REG-DUMP-CONTA            PIC X(300).

       FD  ARQDUMPTRANS.
       01  REG-DUMP-TRANS            PIC X(300).

       WORKING-STORAGE SECTION.
       01  WS-CTRL.
           05  FS-CONTAS             PIC XX.
               88  FS-OK             VALUE '00'.
               88  FS-EOF            VALUE '10'.
           05  FS-TRANS              PIC XX.
               88  FS-OK-TRANS       VALUE '00'.
               88  FS-EOF-TRANS      VALUE '10'.
           05  FS-DUMP-CONTAS        PIC XX.
           05  FS-DUMP-TRANS         PIC XX.

       01  WS-VALOR-EDT              PIC -(11)9,99.
       01  WS-CTR-CONTAS             PIC 9(8) VALUE ZEROS.
       01  WS-CTR-TRANS              PIC 9(8) VALUE ZEROS.

       PROCEDURE DIVISION.
       0000-PRINCIPAL.
           DISPLAY 'BANKEXPORT: exportando BANKACCT.DAT/BANKTRAN.DAT...'
           OPEN INPUT ARQCONTAS
           OPEN OUTPUT ARQDUMPCONTAS
           PERFORM UNTIL FS-EOF
               READ ARQCONTAS NEXT
               IF NOT FS-EOF
                   PERFORM 1000-EXPORTAR-CONTA
               END-IF
           END-PERFORM
           CLOSE ARQCONTAS ARQDUMPCONTAS

           OPEN INPUT ARQTRANS
           OPEN OUTPUT ARQDUMPTRANS
           PERFORM UNTIL FS-EOF-TRANS
               READ ARQTRANS NEXT
               IF NOT FS-EOF-TRANS
                   PERFORM 2000-EXPORTAR-TRANS
               END-IF
           END-PERFORM
           CLOSE ARQTRANS ARQDUMPTRANS

           DISPLAY 'CONTAS EXPORTADAS: ' WS-CTR-CONTAS
           DISPLAY 'TRANSACOES EXPORTADAS: ' WS-CTR-TRANS
           STOP RUN.

       1000-EXPORTAR-CONTA.
           MOVE REG-CONTA-SALDO TO WS-VALOR-EDT
           MOVE SPACES TO REG-DUMP-CONTA
           STRING 'CONTA|' REG-CONTA-NUM '|' REG-CONTA-CPF '|'
                  REG-CONTA-TIPO '|' REG-CONTA-STATUS '|'
                  FUNCTION TRIM(WS-VALOR-EDT) '|'
                  DELIMITED SIZE INTO REG-DUMP-CONTA
           WRITE REG-DUMP-CONTA
           ADD 1 TO WS-CTR-CONTAS.

       2000-EXPORTAR-TRANS.
           MOVE REG-TRANS-VALOR TO WS-VALOR-EDT
           MOVE SPACES TO REG-DUMP-TRANS
           STRING 'TRANS|' REG-TRANS-ID '|' REG-TRANS-CONTA-ORG '|'
                  REG-TRANS-CONTA-DEST '|' REG-TRANS-TIPO '|'
                  FUNCTION TRIM(WS-VALOR-EDT) '|' REG-TRANS-STATUS '|'
                  DELIMITED SIZE INTO REG-DUMP-TRANS
           WRITE REG-DUMP-TRANS
           ADD 1 TO WS-CTR-TRANS.
