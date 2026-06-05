      *===============================================================
      * BANKCARD.COB - Modulo de Cartoes Bancarios
      * Sistema Bancario COBOL
      * Versao: 1.0
      *===============================================================
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
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CONTINUAR         VALUE 'S'.
               88  PARAR             VALUE 'N'.

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
      *    16 digitos: data(8) || conta(8 ultimos digitos)
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
           MOVE WS-CONTA-BUF TO REG-CONTA-CARD
           SUBTRACT WS-VALOR-PAG FROM CARD-CONTA-SALDO
           MOVE FUNCTION CURRENT-DATE(1:8) TO CARD-CONTA-DT-ATUA
           REWRITE REG-CONTA-CARD
           IF NOT FS-OK-CONTAS
               DISPLAY 'ERRO CONTA: ' FS-CONTAS
               MOVE 9 TO LS-CODIGO
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
