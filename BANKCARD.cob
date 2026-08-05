       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKCARD.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS CARD-CONTA-NUM
               FILE STATUS IS FS-CONTAS.

           SELECT ARQCARTAO ASSIGN TO 'BANKCART.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS CART-NUMERO
               ALTERNATE RECORD KEY IS CART-CONTA
                   WITH DUPLICATES
               FILE STATUS IS FS-CARTAO.

           SELECT ARQTRANS ASSIGN TO 'BANKTRAN.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS CARD-TRANS-ID
               FILE STATUS IS FS-TRANS.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONTAS.
       01  REG-CONTA-CARD.
           05  CARD-CONTA-NUM        PIC 9(10).
           05  CARD-CONTA-AGENCIA    PIC 9(4).
           05  CARD-CONTA-DIGITO     PIC 9(1).
           05  CARD-CONTA-TIPO       PIC X(2).
           05  CARD-CONTA-STATUS     PIC X(1).
           05  CARD-CONTA-SALDO      PIC S9(13)V99 COMP-3.
           05  CARD-CONTA-LIMITE     PIC S9(11)V99 COMP-3.
           05  CARD-CONTA-TITULAR    PIC X(60).
           05  CARD-CONTA-CPF        PIC X(11).
           05  CARD-CONTA-EMAIL      PIC X(80).
           05  CARD-CONTA-FONE       PIC X(15).
           05  CARD-CONTA-DT-ABER    PIC 9(8).
           05  CARD-CONTA-DT-ATUA    PIC 9(8).
           05  CARD-CONTA-SENHA      PIC X(64).

       FD  ARQCARTAO.
       01  REG-CARTAO.
           05  CART-NUMERO           PIC 9(16).
           05  CART-CONTA            PIC 9(10).
           05  CART-TIPO             PIC X(1).
           05  CART-TITULAR          PIC X(60).
           05  CART-LIMITE           PIC S9(11)V99 COMP-3.
           05  CART-LIMITE-DISP      PIC S9(11)V99 COMP-3.
           05  CART-FATURA-ATU       PIC S9(13)V99 COMP-3.
           05  CART-DT-VENCTO        PIC 9(8).
           05  CART-DT-EMISSAO       PIC 9(8).
           05  CART-EXPIRY           PIC 9(6).
           05  CART-CVV-HASH         PIC X(64).
           05  CART-STATUS           PIC X(1).
           05  CART-BANDEIRA         PIC X(10).

       FD  ARQTRANS.
       01  REG-TRANS-CARD.
           05  CARD-TRANS-ID         PIC 9(15).
           05  CARD-TRANS-ORIG       PIC 9(10).
           05  CARD-TRANS-DEST       PIC 9(10).
           05  CARD-TRANS-TIPO       PIC X(3).
           05  CARD-TRANS-VALOR      PIC S9(13)V99 COMP-3.
           05  CARD-TRANS-DATA       PIC 9(8).
           05  CARD-TRANS-HORA       PIC 9(6).
           05  CARD-TRANS-DESCR      PIC X(100).
           05  CARD-TRANS-STATUS     PIC X(1).
           05  CARD-TRANS-NSU        PIC 9(12).
           05  CARD-TRANS-CANAL      PIC X(10).

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       01  WS-CTRL.
           05  FS-CONTAS             PIC XX.
               88  FS-OK-CONTAS      VALUE '00'.
               88  FS-NFD-CONTA      VALUE '23'.
           05  FS-CARTAO             PIC XX.
               88  FS-OK-CART        VALUE '00'.
               88  FS-EOF-CART       VALUE '10'.
               88  FS-DUP-CART       VALUE '22'.
               88  FS-NFD-CART       VALUE '23'.
           05  FS-TRANS              PIC XX.
               88  FS-OK-TRANS       VALUE '00'.
           05  FS-BRIDGE             PIC XX.
               88  FS-BRIDGE-OK      VALUE '00'.
               88  FS-BRIDGE-EOF     VALUE '10'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CONTINUAR         VALUE 'S'.
               88  PARAR             VALUE 'N'.

       01  WS-BRIDGE.
           05  WS-BR-OUTFILE          PIC X(40).
           05  WS-BR-CMD              PIC X(250).
           05  WS-BR-CONTA-E          PIC Z(9)9.
           05  WS-BR-ID-E             PIC Z(11)9.
           05  WS-BR-VALOR-INT-N      PIC 9(11).
           05  WS-BR-VALOR-INT-E      PIC Z(10)9.
           05  WS-BR-VALOR-DEC        PIC 99.
           05  WS-BR-VALOR-STR        PIC X(20).
           05  WS-BR-LINE             PIC X(200).
           05  WS-BR-KEY              PIC X(30).
           05  WS-BR-VAL              PIC X(160).
           05  WS-BR-OK               PIC 9 VALUE 0.
           05  WS-BR-ERROR            PIC X(150) VALUE SPACES.
           05  WS-BR-SALDO-STR        PIC X(30).
           05  WS-BR-ID-STR           PIC X(21).

       01  WS-DADOS.
           05  WS-CONTA-NUM          PIC 9(10).
           05  WS-CONTA-SALDO        PIC S9(13)V99 COMP-3.
           05  WS-CONTA-LIMITE       PIC S9(11)V99 COMP-3.
           05  WS-CONTA-STATUS       PIC X(1).
           05  WS-CONTA-TITULAR      PIC X(60).
           05  WS-CONTA-BUF          PIC X(295).
           05  WS-CART-NUM-SEL       PIC 9(16).
           05  WS-CART-TIPO-SEL      PIC X(1).
           05  WS-LIMITE-SEL         PIC S9(11)V99 COMP-3.
           05  WS-VALOR-PAG          PIC S9(13)V99 COMP-3.
           05  WS-NOVO-LIMITE        PIC S9(11)V99 COMP-3.

       01  WS-EXIB.
           05  WS-LIM-EXIB           PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-FAT-EXIB           PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-VAL-EXIB           PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.

       01  WS-ID-CTRL.
           05  WS-ID-DT              PIC 9(8).
           05  WS-ID-HR              PIC 9(6).
           05  WS-TRANS-ID           PIC 9(15).
           05  WS-CART-GERADO        PIC 9(16).

       01  WS-VIRTUAL.
           05  WS-VIRT-NUMERO        PIC 9(16).
           05  WS-VIRT-CVV           PIC 9(3).
           05  WS-VIRT-EXPIRY        PIC X(7).
           05  WS-VIRT-EXIB          PIC 9999B9999B9999B9999.
           05  WS-VIRT-AUX           PIC 9(10).

       01  WS-COMPRA.
           05  WS-COMP-VALOR         PIC S9(13)V99 COMP-3.
           05  WS-COMP-DESCR         PIC X(60).
           05  WS-COMP-PARC          PIC 9(2).
           05  WS-COMP-PARC-REST     PIC Z9.
           05  WS-COMP-PARC-VAL      PIC S9(13)V99 COMP-3.
           05  WS-COMP-IDX           PIC 9(2).
           05  WS-COMP-EXIB          PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-COMP-PARC-EXIB     PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL.
           OPEN I-O ARQCONTAS ARQTRANS
           OPEN I-O ARQCARTAO
           IF FS-CARTAO = '35'
               OPEN OUTPUT ARQCARTAO
               CLOSE ARQCARTAO
               OPEN I-O ARQCARTAO
           END-IF
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-ID-DT
           MOVE FUNCTION CURRENT-DATE(9:6) TO WS-ID-HR
           COMPUTE WS-TRANS-ID =
               FUNCTION NUMVAL(WS-ID-DT) * 10000000 +
               FUNCTION NUMVAL(WS-ID-HR) * 10
           PERFORM 1000-MENU UNTIL PARAR
           CLOSE ARQCONTAS ARQTRANS ARQCARTAO
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU.
           DISPLAY '----------------------------------------'
           DISPLAY ' CARTOES BANCARIOS'
           DISPLAY '----------------------------------------'
           DISPLAY ' 01. Emitir Cartao'
           DISPLAY ' 02. Consultar Cartao'
           DISPLAY ' 03. Bloquear Cartao'
           DISPLAY ' 04. Desbloquear Cartao'
           DISPLAY ' 05. Alterar Limite de Credito'
           DISPLAY ' 06. Consultar Fatura'
           DISPLAY ' 07. Pagar Fatura'
           DISPLAY ' 08. Listar Cartoes da Conta'
           DISPLAY ' 09. Cartao Virtual (fixo por conta)'
           DISPLAY ' 10. Compra no Debito'
           DISPLAY ' 11. Compra no Credito'
           DISPLAY ' 12. Compra Parcelada'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01'  PERFORM 2000-EMITIR
               WHEN '02'  PERFORM 3000-CONSULTAR
               WHEN '03'  PERFORM 4000-BLOQUEAR
               WHEN '04'  PERFORM 5000-DESBLOQUEAR
               WHEN '05'  PERFORM 6000-ALTERAR-LIMITE
               WHEN '06'  PERFORM 7000-FATURA
               WHEN '07'  PERFORM 8000-PAGAR-FATURA
               WHEN '08'  PERFORM 9000-LISTAR
               WHEN '09'  PERFORM A000-CARTAO-VIRTUAL
               WHEN '10'  PERFORM B000-COMPRA-DEBITO
               WHEN '11'  PERFORM C000-COMPRA-CREDITO
               WHEN '12'  PERFORM D000-COMPRA-PARCELADA
               WHEN '00'  MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-EMITIR.
           DISPLAY 'Conta vinculada: '
           ACCEPT WS-CONTA-NUM
           PERFORM 2100-BUSCAR-CONTA
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Tipo (D=Debito C=Credito): '
           ACCEPT WS-CART-TIPO-SEL
           IF WS-CART-TIPO-SEL NOT = 'D' AND
              WS-CART-TIPO-SEL NOT = 'C'
               DISPLAY 'TIPO INVALIDO - usando Debito'
               MOVE 'D' TO WS-CART-TIPO-SEL
           END-IF
           IF WS-CART-TIPO-SEL = 'C'
               DISPLAY 'Limite de credito: '
               ACCEPT WS-LIMITE-SEL
               IF WS-LIMITE-SEL <= ZEROS
                   DISPLAY 'LIMITE INVALIDO'
                   MOVE 3 TO LS-CODIGO
                   EXIT PARAGRAPH
               END-IF
           ELSE
               MOVE ZEROS TO WS-LIMITE-SEL
           END-IF
           PERFORM 2200-GERAR-NUMERO
           MOVE WS-CART-GERADO     TO CART-NUMERO
           MOVE WS-CONTA-NUM       TO CART-CONTA
           MOVE WS-CART-TIPO-SEL   TO CART-TIPO
           MOVE WS-CONTA-TITULAR   TO CART-TITULAR
           MOVE WS-LIMITE-SEL      TO CART-LIMITE
           MOVE WS-LIMITE-SEL      TO CART-LIMITE-DISP
           MOVE ZEROS              TO CART-FATURA-ATU
           MOVE FUNCTION CURRENT-DATE(1:8) TO CART-DT-EMISSAO
           MOVE FUNCTION CURRENT-DATE(1:8) TO CART-DT-VENCTO
           MOVE FUNCTION CURRENT-DATE(1:6) TO CART-EXPIRY
           MOVE SPACES             TO CART-CVV-HASH
           MOVE 'A'                TO CART-STATUS
           MOVE 'ELO'              TO CART-BANDEIRA
           WRITE REG-CARTAO
           IF FS-OK-CART OR FS-DUP-CART
               DISPLAY 'CARTAO EMITIDO: ' WS-CART-GERADO
               DISPLAY 'Tipo: ' WS-CART-TIPO-SEL
                       ' | Bandeira: ELO'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO AO EMITIR: ' FS-CARTAO
               MOVE 9 TO LS-CODIGO
           END-IF.

       2100-BUSCAR-CONTA.
           MOVE WS-CONTA-NUM TO CARD-CONTA-NUM
           READ ARQCONTAS KEY IS CARD-CONTA-NUM
           IF FS-NFD-CONTA
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
           ELSE
               MOVE REG-CONTA-CARD    TO WS-CONTA-BUF
               MOVE CARD-CONTA-SALDO  TO WS-CONTA-SALDO
               MOVE CARD-CONTA-LIMITE TO WS-CONTA-LIMITE
               MOVE CARD-CONTA-STATUS TO WS-CONTA-STATUS
               MOVE CARD-CONTA-TITULAR TO WS-CONTA-TITULAR
               IF WS-CONTA-STATUS NOT = 'A'
                   DISPLAY 'CONTA INATIVA'
                   MOVE 4 TO LS-CODIGO
               ELSE
                   MOVE 0 TO LS-CODIGO
               END-IF
           END-IF.

       2200-GERAR-NUMERO.
           COMPUTE WS-CART-GERADO =
               FUNCTION NUMVAL(WS-ID-DT) * 100000000 +
               FUNCTION MOD(WS-CONTA-NUM 100000000).

       3000-CONSULTAR.
           DISPLAY 'Numero do Cartao (16 digitos): '
           ACCEPT WS-CART-NUM-SEL
           MOVE WS-CART-NUM-SEL TO CART-NUMERO
           READ ARQCARTAO KEY IS CART-NUMERO
           IF FS-NFD-CART
               DISPLAY 'CARTAO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
           ELSE
               MOVE CART-LIMITE-DISP TO WS-LIM-EXIB
               MOVE CART-FATURA-ATU  TO WS-FAT-EXIB
               DISPLAY '--- CARTAO ---'
               DISPLAY 'Numero  : ' CART-NUMERO
               DISPLAY 'Titular : ' CART-TITULAR
               DISPLAY 'Tipo    : ' CART-TIPO
               DISPLAY 'Bandeira: ' CART-BANDEIRA
               DISPLAY 'Limite  : R$ ' WS-LIM-EXIB
               DISPLAY 'Fatura  : R$ ' WS-FAT-EXIB
               DISPLAY 'Emissao : ' CART-DT-EMISSAO
               DISPLAY 'Status  : ' CART-STATUS
               MOVE 0 TO LS-CODIGO
           END-IF.

       4000-BLOQUEAR.
           DISPLAY 'Numero do Cartao: '
           ACCEPT WS-CART-NUM-SEL
           MOVE WS-CART-NUM-SEL TO CART-NUMERO
           READ ARQCARTAO KEY IS CART-NUMERO
           IF FS-NFD-CART
               DISPLAY 'CARTAO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF CART-STATUS = 'B'
               DISPLAY 'CARTAO JA BLOQUEADO'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE 'B' TO CART-STATUS
           REWRITE REG-CARTAO
           DISPLAY 'CARTAO BLOQUEADO COM SUCESSO'
           MOVE 0 TO LS-CODIGO.

       5000-DESBLOQUEAR.
           DISPLAY 'Numero do Cartao: '
           ACCEPT WS-CART-NUM-SEL
           MOVE WS-CART-NUM-SEL TO CART-NUMERO
           READ ARQCARTAO KEY IS CART-NUMERO
           IF FS-NFD-CART
               DISPLAY 'CARTAO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF CART-STATUS NOT = 'B'
               DISPLAY 'CARTAO NAO ESTA BLOQUEADO'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE 'A' TO CART-STATUS
           REWRITE REG-CARTAO
           DISPLAY 'CARTAO DESBLOQUEADO COM SUCESSO'
           MOVE 0 TO LS-CODIGO.

       6000-ALTERAR-LIMITE.
           DISPLAY 'Numero do Cartao: '
           ACCEPT WS-CART-NUM-SEL
           MOVE WS-CART-NUM-SEL TO CART-NUMERO
           READ ARQCARTAO KEY IS CART-NUMERO
           IF FS-NFD-CART
               DISPLAY 'CARTAO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF CART-TIPO NOT = 'C'
               DISPLAY 'ALTERACAO DE LIMITE APENAS PARA CREDITO'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Novo limite: '
           ACCEPT WS-NOVO-LIMITE
           IF WS-NOVO-LIMITE <= ZEROS
               DISPLAY 'LIMITE INVALIDO'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE WS-NOVO-LIMITE TO CART-LIMITE
           MOVE WS-NOVO-LIMITE TO CART-LIMITE-DISP
           REWRITE REG-CARTAO
           MOVE WS-NOVO-LIMITE TO WS-LIM-EXIB
           DISPLAY 'LIMITE ALTERADO: R$ ' WS-LIM-EXIB
           MOVE 0 TO LS-CODIGO.

       7000-FATURA.
           DISPLAY 'Numero do Cartao: '
           ACCEPT WS-CART-NUM-SEL
           MOVE WS-CART-NUM-SEL TO CART-NUMERO
           READ ARQCARTAO KEY IS CART-NUMERO
           IF FS-NFD-CART
               DISPLAY 'CARTAO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE CART-FATURA-ATU  TO WS-FAT-EXIB
           MOVE CART-LIMITE-DISP TO WS-LIM-EXIB
           MOVE CART-LIMITE      TO WS-VAL-EXIB
           DISPLAY '--- FATURA ATUAL ---'
           DISPLAY 'Cartao        : ' CART-NUMERO
           DISPLAY 'Titular       : ' CART-TITULAR
           DISPLAY 'Fatura atual  : R$ ' WS-FAT-EXIB
           DISPLAY 'Limite total  : R$ ' WS-VAL-EXIB
           DISPLAY 'Limite dispon : R$ ' WS-LIM-EXIB
           DISPLAY 'Vencimento    : ' CART-DT-VENCTO
           MOVE 0 TO LS-CODIGO.

       8000-PAGAR-FATURA.
           DISPLAY 'Numero do Cartao: '
           ACCEPT WS-CART-NUM-SEL
           MOVE WS-CART-NUM-SEL TO CART-NUMERO
           READ ARQCARTAO KEY IS CART-NUMERO
           IF FS-NFD-CART
               DISPLAY 'CARTAO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF CART-TIPO NOT = 'C'
               DISPLAY 'PAGAMENTO DE FATURA APENAS PARA CREDITO'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF CART-FATURA-ATU <= ZEROS
               DISPLAY 'FATURA ZERADA - SEM DEBITOS'
               MOVE 0 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE CART-CONTA TO WS-CONTA-NUM
           PERFORM 2100-BUSCAR-CONTA
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           MOVE CART-FATURA-ATU TO WS-FAT-EXIB
           DISPLAY 'Fatura: R$ ' WS-FAT-EXIB
           DISPLAY 'Pagar valor total? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO(1:1) = 'S'
               MOVE CART-FATURA-ATU TO WS-VALOR-PAG
           ELSE
               DISPLAY 'Valor a pagar: '
               ACCEPT WS-VALOR-PAG
               IF WS-VALOR-PAG > CART-FATURA-ATU
                   MOVE CART-FATURA-ATU TO WS-VALOR-PAG
               END-IF
           END-IF
           IF WS-VALOR-PAG <= ZEROS
               DISPLAY 'VALOR INVALIDO'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF (WS-CONTA-SALDO + WS-CONTA-LIMITE) < WS-VALOR-PAG
               DISPLAY 'SALDO INSUFICIENTE'
               MOVE 1 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           PERFORM 8050-DEBITAR-RAZAO
           IF WS-BR-OK NOT = 1
               DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
               MOVE 9998 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           SUBTRACT WS-VALOR-PAG FROM CART-FATURA-ATU
           ADD WS-VALOR-PAG TO CART-LIMITE-DISP
           REWRITE REG-CARTAO
           IF NOT FS-OK-CART
               DISPLAY 'ERRO CARTAO: ' FS-CARTAO
               MOVE 9 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-TRANS-ID
           MOVE WS-TRANS-ID    TO CARD-TRANS-ID
           MOVE WS-CONTA-NUM   TO CARD-TRANS-ORIG
           MOVE ZEROS          TO CARD-TRANS-DEST
           MOVE 'FAT'          TO CARD-TRANS-TIPO
           MOVE WS-VALOR-PAG   TO CARD-TRANS-VALOR
           MOVE FUNCTION CURRENT-DATE(1:8) TO CARD-TRANS-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO CARD-TRANS-HORA
           MOVE 'Pagamento de fatura cartao' TO CARD-TRANS-DESCR
           MOVE 'E'            TO CARD-TRANS-STATUS
           MOVE ZEROS          TO CARD-TRANS-NSU
           MOVE 'MODCARD'      TO CARD-TRANS-CANAL
           WRITE REG-TRANS-CARD
           MOVE WS-VALOR-PAG TO WS-VAL-EXIB
           DISPLAY 'FATURA PAGA: R$ ' WS-VAL-EXIB
           MOVE 0 TO LS-CODIGO.

       8050-DEBITAR-RAZAO.
           MOVE WS-CONTA-NUM TO WS-BR-CONTA-E
           MOVE SPACES TO WS-BR-ID-STR
           STRING FUNCTION CURRENT-DATE(1:15) '-'
                  WS-CART-NUM-SEL(10:6) DELIMITED SIZE
                  INTO WS-BR-ID-STR
           COMPUTE WS-BR-VALOR-INT-N =
               FUNCTION INTEGER-PART(WS-VALOR-PAG)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER(
                   (WS-VALOR-PAG - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPC-' FUNCTION CURRENT-DATE(1:15) '.OUT'
                  DELIMITED SIZE INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle CARD '
                  'CARD_BILL_PAYMENT '
                  FUNCTION TRIM(WS-BR-CONTA-E) ' '
                  FUNCTION TRIM(WS-BR-VALOR-STR) ' '
                  FUNCTION TRIM(WS-BR-ID-STR)
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
           END-IF
           IF WS-BR-OK NOT = 1
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPCS-' FUNCTION CURRENT-DATE(1:15) '.OUT'
                  DELIMITED SIZE INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py account '
                  FUNCTION TRIM(WS-BR-CONTA-E)
                  ' --cobol-out ' FUNCTION TRIM(WS-BR-OUTFILE)
                  DELIMITED SIZE INTO WS-BR-CMD
           CALL 'SYSTEM' USING WS-BR-CMD
           IF RETURN-CODE = 0
               OPEN INPUT ARQBRIDGE
               IF FS-BRIDGE-OK
                   PERFORM UNTIL FS-BRIDGE-EOF
                       READ ARQBRIDGE INTO WS-BR-LINE
                       IF NOT FS-BRIDGE-EOF
                           MOVE SPACES TO WS-BR-KEY WS-BR-VAL
                           UNSTRING WS-BR-LINE DELIMITED BY '='
                               INTO WS-BR-KEY WS-BR-VAL
                           IF FUNCTION TRIM(WS-BR-KEY) =
                              'LEDGER_BALANCE'
                               MOVE FUNCTION TRIM(WS-BR-VAL)
                                   TO WS-BR-SALDO-STR
                               MOVE WS-CONTA-BUF TO REG-CONTA-CARD
                               COMPUTE CARD-CONTA-SALDO =
                                   FUNCTION NUMVAL(WS-BR-SALDO-STR)
                               MOVE FUNCTION CURRENT-DATE(1:8) TO
                                   CARD-CONTA-DT-ATUA
                               REWRITE REG-CONTA-CARD
                           END-IF
                       END-IF
                   END-PERFORM
                   CLOSE ARQBRIDGE
               END-IF
           END-IF.

       9000-LISTAR.
           DISPLAY 'Conta: '
           ACCEPT WS-CONTA-NUM
           MOVE WS-CONTA-NUM TO CART-CONTA
           START ARQCARTAO KEY = CART-CONTA
           IF FS-NFD-CART
               DISPLAY 'NENHUM CARTAO ENCONTRADO'
               MOVE 0 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY '--- CARTOES DA CONTA ' WS-CONTA-NUM ' ---'
           PERFORM UNTIL FS-EOF-CART
               READ ARQCARTAO NEXT
               IF FS-OK-CART
                   IF CART-CONTA = WS-CONTA-NUM
                       MOVE CART-FATURA-ATU TO WS-FAT-EXIB
                       MOVE CART-LIMITE-DISP TO WS-LIM-EXIB
                       DISPLAY CART-NUMERO
                               ' | Tipo: ' CART-TIPO
                               ' | ' CART-BANDEIRA
                               ' | Fat: R$ ' WS-FAT-EXIB
                               ' | Lim: R$ ' WS-LIM-EXIB
                               ' | ' CART-STATUS
                   ELSE
                       MOVE '10' TO FS-CARTAO
                   END-IF
               END-IF
           END-PERFORM
           MOVE 0 TO LS-CODIGO.

       A000-CARTAO-VIRTUAL.
           DISPLAY 'Conta: '
           ACCEPT WS-CONTA-NUM
           PERFORM 2100-BUSCAR-CONTA
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-VIRT-AUX =
               FUNCTION MOD(WS-CONTA-NUM * 9999991 99999999999)
           COMPUTE WS-VIRT-NUMERO =
               4567000000000000 + WS-VIRT-AUX * 10000 +
               FUNCTION MOD(WS-CONTA-NUM 10000)
           COMPUTE WS-VIRT-CVV =
               FUNCTION MOD(WS-CONTA-NUM 900) + 100
           MOVE WS-VIRT-NUMERO TO WS-VIRT-EXIB
           MOVE '12/2030' TO WS-VIRT-EXPIRY
           DISPLAY '========================================'
           DISPLAY '   CARTAO VIRTUAL — BANCO COBOL'
           DISPLAY '========================================'
           DISPLAY 'Titular : ' WS-CONTA-TITULAR
           DISPLAY 'Numero  : ' WS-VIRT-EXIB
           DISPLAY 'Validade: ' WS-VIRT-EXPIRY
           DISPLAY 'CVV     : ' WS-VIRT-CVV
           DISPLAY 'Bandeira: ELO VIRTUAL'
           DISPLAY '----------------------------------------'
           DISPLAY 'CARTAO VIRTUAL — uso online exclusivo'
           DISPLAY 'Numero FIXO e INALTERAVEL por conta'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       B000-COMPRA-DEBITO.
           DISPLAY 'Numero do Cartao Debito: '
           ACCEPT WS-CART-NUM-SEL
           MOVE WS-CART-NUM-SEL TO CART-NUMERO
           READ ARQCARTAO KEY IS CART-NUMERO
           IF FS-NFD-CART
               DISPLAY 'CARTAO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF CART-TIPO NOT = 'D'
               DISPLAY 'OPERACAO VALIDA APENAS PARA CARTAO DEBITO'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF CART-STATUS NOT = 'A'
               DISPLAY 'CARTAO INATIVO/BLOQUEADO'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE CART-CONTA TO WS-CONTA-NUM
           PERFORM 2100-BUSCAR-CONTA
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Descricao da compra: '
           ACCEPT WS-COMP-DESCR
           DISPLAY 'Valor: '
           ACCEPT WS-COMP-VALOR
           IF WS-COMP-VALOR <= ZEROS
               DISPLAY 'VALOR INVALIDO'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF (WS-CONTA-SALDO + WS-CONTA-LIMITE) < WS-COMP-VALOR
               DISPLAY 'SALDO INSUFICIENTE'
               MOVE 1 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE WS-CONTA-BUF TO REG-CONTA-CARD
           SUBTRACT WS-COMP-VALOR FROM CARD-CONTA-SALDO
           MOVE FUNCTION CURRENT-DATE(1:8) TO CARD-CONTA-DT-ATUA
           REWRITE REG-CONTA-CARD
           IF NOT FS-OK-CONTAS
               DISPLAY 'ERRO AO DEBITAR CONTA: ' FS-CONTAS
               MOVE 9 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-TRANS-ID
           MOVE WS-TRANS-ID    TO CARD-TRANS-ID
           MOVE WS-CONTA-NUM   TO CARD-TRANS-ORIG
           MOVE ZEROS          TO CARD-TRANS-DEST
           MOVE 'DEB'          TO CARD-TRANS-TIPO
           MOVE WS-COMP-VALOR  TO CARD-TRANS-VALOR
           MOVE FUNCTION CURRENT-DATE(1:8) TO CARD-TRANS-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO CARD-TRANS-HORA
           MOVE WS-COMP-DESCR  TO CARD-TRANS-DESCR
           MOVE 'E'            TO CARD-TRANS-STATUS
           MOVE ZEROS          TO CARD-TRANS-NSU
           MOVE 'MODCARD'      TO CARD-TRANS-CANAL
           WRITE REG-TRANS-CARD
           MOVE WS-COMP-VALOR TO WS-COMP-EXIB
           DISPLAY 'COMPRA DEBITO APROVADA: R$ ' WS-COMP-EXIB
           MOVE 0 TO LS-CODIGO.

       C000-COMPRA-CREDITO.
           DISPLAY 'Numero do Cartao Credito: '
           ACCEPT WS-CART-NUM-SEL
           MOVE WS-CART-NUM-SEL TO CART-NUMERO
           READ ARQCARTAO KEY IS CART-NUMERO
           IF FS-NFD-CART
               DISPLAY 'CARTAO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF CART-TIPO NOT = 'C'
               DISPLAY 'OPERACAO VALIDA APENAS PARA CARTAO CREDITO'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF CART-STATUS NOT = 'A'
               DISPLAY 'CARTAO INATIVO/BLOQUEADO'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Descricao da compra: '
           ACCEPT WS-COMP-DESCR
           DISPLAY 'Valor: '
           ACCEPT WS-COMP-VALOR
           IF WS-COMP-VALOR <= ZEROS
               DISPLAY 'VALOR INVALIDO'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF WS-COMP-VALOR > CART-LIMITE-DISP
               MOVE CART-LIMITE-DISP TO WS-LIM-EXIB
               DISPLAY 'LIMITE DISPONIVEL INSUFICIENTE: R$ ' WS-LIM-EXIB
               MOVE 1 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           SUBTRACT WS-COMP-VALOR FROM CART-LIMITE-DISP
           ADD WS-COMP-VALOR TO CART-FATURA-ATU
           REWRITE REG-CARTAO
           IF NOT FS-OK-CART
               DISPLAY 'ERRO AO GRAVAR CARTAO: ' FS-CARTAO
               MOVE 9 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-TRANS-ID
           MOVE WS-TRANS-ID    TO CARD-TRANS-ID
           MOVE CART-CONTA     TO CARD-TRANS-ORIG
           MOVE ZEROS          TO CARD-TRANS-DEST
           MOVE 'CRT'          TO CARD-TRANS-TIPO
           MOVE WS-COMP-VALOR  TO CARD-TRANS-VALOR
           MOVE FUNCTION CURRENT-DATE(1:8) TO CARD-TRANS-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO CARD-TRANS-HORA
           MOVE WS-COMP-DESCR  TO CARD-TRANS-DESCR
           MOVE 'E'            TO CARD-TRANS-STATUS
           MOVE ZEROS          TO CARD-TRANS-NSU
           MOVE 'MODCARD'      TO CARD-TRANS-CANAL
           WRITE REG-TRANS-CARD
           MOVE WS-COMP-VALOR TO WS-COMP-EXIB
           MOVE CART-FATURA-ATU TO WS-FAT-EXIB
           DISPLAY 'COMPRA CREDITO APROVADA: R$ ' WS-COMP-EXIB
           DISPLAY 'Fatura atual  : R$ ' WS-FAT-EXIB
           MOVE 0 TO LS-CODIGO.

       D000-COMPRA-PARCELADA.
           DISPLAY 'Numero do Cartao Credito: '
           ACCEPT WS-CART-NUM-SEL
           MOVE WS-CART-NUM-SEL TO CART-NUMERO
           READ ARQCARTAO KEY IS CART-NUMERO
           IF FS-NFD-CART
               DISPLAY 'CARTAO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF CART-TIPO NOT = 'C'
               DISPLAY 'PARCELAMENTO APENAS PARA CARTAO CREDITO'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF CART-STATUS NOT = 'A'
               DISPLAY 'CARTAO INATIVO/BLOQUEADO'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Descricao da compra: '
           ACCEPT WS-COMP-DESCR
           DISPLAY 'Valor total: '
           ACCEPT WS-COMP-VALOR
           IF WS-COMP-VALOR <= ZEROS
               DISPLAY 'VALOR INVALIDO'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Numero de parcelas (2-24): '
           ACCEPT WS-COMP-PARC
           IF WS-COMP-PARC < 2 OR WS-COMP-PARC > 24
               DISPLAY 'PARCELAS INVALIDAS (2-24)'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF WS-COMP-VALOR > CART-LIMITE-DISP
               MOVE CART-LIMITE-DISP TO WS-LIM-EXIB
               DISPLAY 'LIMITE DISPONIVEL INSUFICIENTE: R$ ' WS-LIM-EXIB
               MOVE 1 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-COMP-PARC-VAL ROUNDED =
               WS-COMP-VALOR / WS-COMP-PARC
           MOVE WS-COMP-VALOR     TO WS-COMP-EXIB
           MOVE WS-COMP-PARC-VAL  TO WS-COMP-PARC-EXIB
           DISPLAY 'Plano de parcelamento:'
           DISPLAY '  Total     : R$ ' WS-COMP-EXIB
           DISPLAY '  Parcelas  : ' WS-COMP-PARC 'x R$ '
                   WS-COMP-PARC-EXIB ' (sem juros)'
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO(1:1) NOT = 'S'
               DISPLAY 'CANCELADO'
               MOVE 0 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           SUBTRACT WS-COMP-VALOR FROM CART-LIMITE-DISP
           ADD WS-COMP-PARC-VAL TO CART-FATURA-ATU
           REWRITE REG-CARTAO
           IF NOT FS-OK-CART
               DISPLAY 'ERRO AO GRAVAR CARTAO: ' FS-CARTAO
               MOVE 9 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-TRANS-ID
           MOVE WS-TRANS-ID    TO CARD-TRANS-ID
           MOVE CART-CONTA     TO CARD-TRANS-ORIG
           MOVE ZEROS          TO CARD-TRANS-DEST
           MOVE 'CRT'          TO CARD-TRANS-TIPO
           MOVE WS-COMP-VALOR  TO CARD-TRANS-VALOR
           MOVE FUNCTION CURRENT-DATE(1:8) TO CARD-TRANS-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO CARD-TRANS-HORA
           STRING WS-COMP-DESCR DELIMITED SIZE
                  ' (' DELIMITED SIZE
                  WS-COMP-PARC DELIMITED SIZE
                  'x)' DELIMITED SIZE
                  INTO CARD-TRANS-DESCR
           MOVE 'E'            TO CARD-TRANS-STATUS
           MOVE WS-COMP-PARC   TO CARD-TRANS-NSU
           MOVE 'MODCARD'      TO CARD-TRANS-CANAL
           WRITE REG-TRANS-CARD
           MOVE WS-COMP-PARC-VAL TO WS-COMP-PARC-EXIB
           DISPLAY 'PARCELAMENTO APROVADO!'
           DISPLAY 'Fatura este mes: R$ ' WS-COMP-PARC-EXIB
           COMPUTE WS-COMP-PARC-REST = WS-COMP-PARC - 1
           DISPLAY 'Proximas parcelas: ' WS-COMP-PARC-REST
                   ' x R$ ' WS-COMP-PARC-EXIB
           MOVE 0 TO LS-CODIGO.
