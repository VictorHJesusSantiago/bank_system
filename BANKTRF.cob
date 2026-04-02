      *===============================================================
      * BANKTRF.COB - Modulo de Transferencias
      *===============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKTRF.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS TRF-CONTA-NUM
               FILE STATUS IS FS-CONTAS.

           SELECT ARQTRANS ASSIGN TO 'BANKTRAN.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS TRF-TRANS-ID
               FILE STATUS IS FS-TRANS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONTAS.
       01  REG-CONTA.
           05  TRF-CONTA-NUM         PIC 9(10).
           05  TRF-CONTA-AGENCIA     PIC 9(4).
           05  TRF-CONTA-DIGITO      PIC 9(1).
           05  TRF-CONTA-TIPO        PIC X(2).
           05  TRF-CONTA-STATUS      PIC X(1).
           05  TRF-CONTA-SALDO       PIC S9(13)V99 COMP-3.
           05  TRF-CONTA-LIMITE      PIC S9(11)V99 COMP-3.
           05  TRF-CONTA-TITULAR     PIC X(60).
           05  TRF-CONTA-CPF         PIC X(11).
           05  TRF-CONTA-EMAIL       PIC X(80).
           05  TRF-CONTA-TELEFONE    PIC X(15).
           05  TRF-CONTA-DT-ABERTURA PIC 9(8).
           05  TRF-CONTA-DT-ATUALIZACAO PIC 9(8).
           05  TRF-CONTA-SENHA-HASH  PIC X(64).

       FD  ARQTRANS.
       01  REG-TRANS.
           05  TRF-TRANS-ID          PIC 9(15).
           05  TRF-TRANS-CONTA-ORG   PIC 9(10).
           05  TRF-TRANS-CONTA-DEST  PIC 9(10).
           05  TRF-TRANS-TIPO        PIC X(3).
           05  TRF-TRANS-VALOR       PIC S9(13)V99 COMP-3.
           05  TRF-TRANS-DATA        PIC 9(8).
           05  TRF-TRANS-HORA        PIC 9(6).
           05  TRF-TRANS-DESCRICAO   PIC X(100).
           05  TRF-TRANS-STATUS      PIC X(1).
           05  TRF-TRANS-NSU         PIC 9(12).
           05  TRF-TRANS-CANAL       PIC X(10).

       WORKING-STORAGE SECTION.
       01  WS-CTRL.
           05  FS-CONTAS             PIC XX.
               88  FS-OK             VALUE '00'.
               88  FS-EOF            VALUE '10'.
               88  FS-NFD            VALUE '23'.
           05  FS-TRANS              PIC XX.
               88  FS-OK-TRANS       VALUE '00'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CONTINUAR         VALUE 'S'.
               88  PARAR             VALUE 'N'.

       01  WS-ORIGEM.
           05  WS-ORG-NUM            PIC 9(10).
           05  WS-ORG-SALDO          PIC S9(13)V99 COMP-3.
           05  WS-ORG-LIMITE         PIC S9(11)V99 COMP-3.
           05  WS-ORG-STATUS         PIC X(1).
           05  WS-ORG-BUF            PIC X(283).

       01  WS-DESTINO.
           05  WS-DES-NUM            PIC 9(10).
           05  WS-DES-SALDO          PIC S9(13)V99 COMP-3.
           05  WS-DES-BUF            PIC X(283).

       01  WS-DADOS.
           05  WS-VALOR              PIC S9(13)V99 COMP-3.
           05  WS-TAXA               PIC S9(5)V99 COMP-3.
           05  WS-TIPO               PIC X(3).
           05  WS-DISPONIVEL         PIC S9(13)V99 COMP-3.
           05  WS-ID                 PIC 9(15).
           05  WS-VAL-DISP           PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-PIX-CHAVE          PIC X(80).
           05  WS-PIX-TIPO           PIC X(1).
           05  WS-ACHOU-DEST         PIC X VALUE 'N'.

       01  WS-SCAN.
           05  WS-SCAN-EMAIL         PIC X(80).
           05  WS-SCAN-TEL           PIC X(15).

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL.
           OPEN I-O ARQCONTAS ARQTRANS
           PERFORM 1000-MENU UNTIL PARAR
           CLOSE ARQCONTAS ARQTRANS
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU.
           DISPLAY '----------------------------------------'
           DISPLAY ' TRANSFERENCIAS'
           DISPLAY '----------------------------------------'
           DISPLAY ' 01. TED (taxa R$ 14,90)'
           DISPLAY ' 02. DOC (taxa R$ 5,80)'
           DISPLAY ' 03. PIX (taxa R$ 0,00)'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01'
                   MOVE 'TED' TO WS-TIPO
                   MOVE 14,90 TO WS-TAXA
                   PERFORM 2000-EXECUTAR
               WHEN '02'
                   MOVE 'DOC' TO WS-TIPO
                   MOVE 5,80 TO WS-TAXA
                   PERFORM 2000-EXECUTAR
               WHEN '03'
                   MOVE 'PIX' TO WS-TIPO
                   MOVE ZEROS TO WS-TAXA
                   PERFORM 2700-EXECUTAR-PIX
               WHEN '00'
                   MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER
                   DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-EXECUTAR.
           DISPLAY 'Conta Origem: '
           ACCEPT WS-ORG-NUM
           DISPLAY 'Conta Destino: '
           ACCEPT WS-DES-NUM
           DISPLAY 'Valor: '
           ACCEPT WS-VALOR

           PERFORM 2100-LER-ORIGEM
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           PERFORM 2200-LER-DESTINO
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF

           COMPUTE WS-DISPONIVEL = WS-ORG-SALDO + WS-ORG-LIMITE
           IF WS-VALOR <= ZEROS
               DISPLAY 'VALOR INVALIDO'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF (WS-VALOR + WS-TAXA) > WS-DISPONIVEL
               DISPLAY 'SALDO/LIMITE INSUFICIENTE'
               MOVE 1 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF

           SUBTRACT WS-VALOR FROM WS-ORG-SALDO
           SUBTRACT WS-TAXA FROM WS-ORG-SALDO
           ADD WS-VALOR TO WS-DES-SALDO

           PERFORM 2300-GRAVAR-ORIGEM
           PERFORM 2400-GRAVAR-DESTINO
           PERFORM 2500-GRAVAR-TRANS

           MOVE WS-VALOR TO WS-VAL-DISP
           DISPLAY WS-TIPO ' EFETUADA: R$ ' WS-VAL-DISP
           MOVE 0 TO LS-CODIGO.

       2100-LER-ORIGEM.
           MOVE WS-ORG-NUM TO TRF-CONTA-NUM
           READ ARQCONTAS KEY IS TRF-CONTA-NUM
           IF FS-NFD
               DISPLAY 'CONTA ORIGEM NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
           ELSE
               MOVE REG-CONTA TO WS-ORG-BUF
               MOVE TRF-CONTA-SALDO TO WS-ORG-SALDO
               MOVE TRF-CONTA-LIMITE TO WS-ORG-LIMITE
               MOVE TRF-CONTA-STATUS TO WS-ORG-STATUS
               IF WS-ORG-STATUS NOT = 'A'
                   DISPLAY 'CONTA ORIGEM INATIVA'
                   MOVE 4 TO LS-CODIGO
               ELSE
                   MOVE 0 TO LS-CODIGO
               END-IF
           END-IF.

       2200-LER-DESTINO.
           MOVE WS-DES-NUM TO TRF-CONTA-NUM
           READ ARQCONTAS KEY IS TRF-CONTA-NUM
           IF FS-NFD
               DISPLAY 'CONTA DESTINO NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
           ELSE
               MOVE REG-CONTA TO WS-DES-BUF
               MOVE TRF-CONTA-SALDO TO WS-DES-SALDO
               IF TRF-CONTA-STATUS NOT = 'A'
                   DISPLAY 'CONTA DESTINO INATIVA'
                   MOVE 4 TO LS-CODIGO
               ELSE
                   MOVE 0 TO LS-CODIGO
               END-IF
           END-IF.

       2300-GRAVAR-ORIGEM.
           MOVE WS-ORG-BUF TO REG-CONTA
           MOVE WS-ORG-SALDO TO TRF-CONTA-SALDO
           MOVE FUNCTION CURRENT-DATE(1:8) TO TRF-CONTA-DT-ATUALIZACAO
           REWRITE REG-CONTA.

       2400-GRAVAR-DESTINO.
           MOVE WS-DES-BUF TO REG-CONTA
           MOVE WS-DES-SALDO TO TRF-CONTA-SALDO
           MOVE FUNCTION CURRENT-DATE(1:8) TO TRF-CONTA-DT-ATUALIZACAO
           REWRITE REG-CONTA.

       2500-GRAVAR-TRANS.
           MOVE FUNCTION CURRENT-DATE(1:15) TO WS-ID
           MOVE WS-ID TO TRF-TRANS-ID
           MOVE WS-ORG-NUM TO TRF-TRANS-CONTA-ORG
           MOVE WS-DES-NUM TO TRF-TRANS-CONTA-DEST
           MOVE WS-TIPO TO TRF-TRANS-TIPO
           MOVE WS-VALOR TO TRF-TRANS-VALOR
           MOVE FUNCTION CURRENT-DATE(1:8) TO TRF-TRANS-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO TRF-TRANS-HORA
           MOVE 'Transferencia' TO TRF-TRANS-DESCRICAO
           MOVE 'E' TO TRF-TRANS-STATUS
           MOVE 'MODTRF' TO TRF-TRANS-CANAL
           WRITE REG-TRANS.

       2600-LOCALIZAR-DESTINO-PIX.
           MOVE 'N' TO WS-ACHOU-DEST
           MOVE ZEROS TO TRF-CONTA-NUM
           START ARQCONTAS KEY >= TRF-CONTA-NUM
           PERFORM UNTIL FS-EOF OR WS-ACHOU-DEST = 'S'
               READ ARQCONTAS NEXT
               IF FS-OK
                   MOVE TRF-CONTA-EMAIL TO WS-SCAN-EMAIL
                   MOVE TRF-CONTA-TELEFONE TO WS-SCAN-TEL
                   IF WS-PIX-TIPO = 'C'
                      AND TRF-CONTA-CPF = WS-PIX-CHAVE
                       MOVE 'S' TO WS-ACHOU-DEST
                   END-IF
                   IF WS-PIX-TIPO = 'E'
                      AND WS-SCAN-EMAIL = WS-PIX-CHAVE
                       MOVE 'S' TO WS-ACHOU-DEST
                   END-IF
                   IF WS-PIX-TIPO = 'T'
                      AND WS-SCAN-TEL = WS-PIX-CHAVE
                       MOVE 'S' TO WS-ACHOU-DEST
                   END-IF
                   IF WS-ACHOU-DEST = 'S'
                       MOVE REG-CONTA TO WS-DES-BUF
                       MOVE TRF-CONTA-NUM TO WS-DES-NUM
                       MOVE TRF-CONTA-SALDO TO WS-DES-SALDO
                   END-IF
               END-IF
           END-PERFORM
           IF WS-ACHOU-DEST NOT = 'S'
               DISPLAY 'CHAVE PIX NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE WS-DES-BUF TO REG-CONTA
           IF TRF-CONTA-STATUS NOT = 'A'
               DISPLAY 'CONTA DESTINO INATIVA'
               MOVE 4 TO LS-CODIGO
           ELSE
               MOVE 0 TO LS-CODIGO
           END-IF.

       2700-EXECUTAR-PIX.
           DISPLAY 'Conta Origem: '
           ACCEPT WS-ORG-NUM
           DISPLAY 'Tipo de chave PIX (C=CPF E=Email T=Telefone): '
           ACCEPT WS-PIX-TIPO
           DISPLAY 'Chave PIX: '
           ACCEPT WS-PIX-CHAVE
           DISPLAY 'Valor: '
           ACCEPT WS-VALOR

           PERFORM 2100-LER-ORIGEM
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           PERFORM 2600-LOCALIZAR-DESTINO-PIX
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF

           COMPUTE WS-DISPONIVEL = WS-ORG-SALDO + WS-ORG-LIMITE
           IF WS-VALOR <= ZEROS
               DISPLAY 'VALOR INVALIDO'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF WS-VALOR > WS-DISPONIVEL
               DISPLAY 'SALDO/LIMITE INSUFICIENTE'
               MOVE 1 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF

           SUBTRACT WS-VALOR FROM WS-ORG-SALDO
           ADD WS-VALOR TO WS-DES-SALDO

           PERFORM 2300-GRAVAR-ORIGEM
           PERFORM 2400-GRAVAR-DESTINO
           PERFORM 2500-GRAVAR-TRANS

           MOVE WS-VALOR TO WS-VAL-DISP
           DISPLAY 'PIX EFETUADO: R$ ' WS-VAL-DISP
           MOVE 0 TO LS-CODIGO.
