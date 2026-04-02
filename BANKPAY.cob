      *===============================================================
      * BANKPAY.COB - Modulo de Pagamentos
      *===============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKPAY.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS PAY-CONTA-NUM
               FILE STATUS IS FS-CONTAS.

           SELECT ARQTRANS ASSIGN TO 'BANKTRAN.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS PAY-TRANS-ID
               FILE STATUS IS FS-TRANS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONTAS.
       01  REG-CONTA.
           05  PAY-CONTA-NUM         PIC 9(10).
           05  PAY-CONTA-AGENCIA     PIC 9(4).
           05  PAY-CONTA-DIGITO      PIC 9(1).
           05  PAY-CONTA-TIPO        PIC X(2).
           05  PAY-CONTA-STATUS      PIC X(1).
           05  PAY-CONTA-SALDO       PIC S9(13)V99 COMP-3.
           05  PAY-CONTA-LIMITE      PIC S9(11)V99 COMP-3.
           05  PAY-CONTA-TITULAR     PIC X(60).
           05  PAY-CONTA-CPF         PIC X(11).
           05  PAY-CONTA-EMAIL       PIC X(80).
           05  PAY-CONTA-TELEFONE    PIC X(15).
           05  PAY-CONTA-DT-ABERTURA PIC 9(8).
           05  PAY-CONTA-DT-ATUALIZACAO PIC 9(8).
           05  PAY-CONTA-SENHA-HASH  PIC X(64).

       FD  ARQTRANS.
       01  REG-TRANS.
           05  PAY-TRANS-ID          PIC 9(15).
           05  PAY-TRANS-CONTA-ORG   PIC 9(10).
           05  PAY-TRANS-CONTA-DEST  PIC 9(10).
           05  PAY-TRANS-TIPO        PIC X(3).
           05  PAY-TRANS-VALOR       PIC S9(13)V99 COMP-3.
           05  PAY-TRANS-DATA        PIC 9(8).
           05  PAY-TRANS-HORA        PIC 9(6).
           05  PAY-TRANS-DESCRICAO   PIC X(100).
           05  PAY-TRANS-STATUS      PIC X(1).
           05  PAY-TRANS-NSU         PIC 9(12).
           05  PAY-TRANS-CANAL       PIC X(10).

       WORKING-STORAGE SECTION.
       01  WS-CTRL.
           05  FS-CONTAS             PIC XX.
               88  FS-OK             VALUE '00'.
               88  FS-NFD            VALUE '23'.
           05  FS-TRANS              PIC XX.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CONTINUAR         VALUE 'S'.
               88  PARAR             VALUE 'N'.

       01  WS-PAG.
           05  WS-CONTA              PIC 9(10).
           05  WS-VALOR              PIC S9(13)V99 COMP-3.
           05  WS-COD-BARRAS         PIC X(50).
           05  WS-COD-LIMPO          PIC X(44).
           05  WS-COD-LEN            PIC 9(3) VALUE ZEROS.
           05  WS-IDX                PIC 9(3) VALUE ZEROS.
           05  WS-SOMA               PIC 9(9) VALUE ZEROS.
           05  WS-PESO               PIC 99 VALUE 2.
           05  WS-DIG                PIC 9 VALUE 0.
           05  WS-DV-CALC            PIC 99 VALUE 0.
           05  WS-DV-INFORMADO       PIC 9 VALUE 0.
           05  WS-SALDO              PIC S9(13)V99 COMP-3.
           05  WS-LIMITE             PIC S9(11)V99 COMP-3.
           05  WS-DISPONIVEL         PIC S9(13)V99 COMP-3.
           05  WS-CONTA-BUF          PIC X(283).
           05  WS-ID                 PIC 9(15).
           05  WS-DISP               PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.

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
           DISPLAY ' PAGAMENTOS'
           DISPLAY '----------------------------------------'
           DISPLAY ' 01. Pagamento de boleto'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01'
                   PERFORM 2000-PAGAR-BOLETO
               WHEN '00'
                   MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER
                   DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-PAGAR-BOLETO.
           DISPLAY 'Conta para debito: '
           ACCEPT WS-CONTA
           DISPLAY 'Codigo de barras: '
           ACCEPT WS-COD-BARRAS
           PERFORM 2100-VALIDAR-CODIGO-BARRAS
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Valor do boleto: '
           ACCEPT WS-VALOR

           IF WS-VALOR <= ZEROS
               DISPLAY 'VALOR INVALIDO'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF

           MOVE WS-CONTA TO PAY-CONTA-NUM
           READ ARQCONTAS KEY IS PAY-CONTA-NUM
           IF FS-NFD
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF

           IF PAY-CONTA-STATUS NOT = 'A'
               DISPLAY 'CONTA INATIVA'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF

           MOVE REG-CONTA TO WS-CONTA-BUF
           MOVE PAY-CONTA-SALDO TO WS-SALDO
           MOVE PAY-CONTA-LIMITE TO WS-LIMITE
           COMPUTE WS-DISPONIVEL = WS-SALDO + WS-LIMITE

           IF WS-VALOR > WS-DISPONIVEL
               DISPLAY 'SALDO/LIMITE INSUFICIENTE'
               MOVE 1 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF

           SUBTRACT WS-VALOR FROM WS-SALDO
           MOVE WS-CONTA-BUF TO REG-CONTA
           MOVE WS-SALDO TO PAY-CONTA-SALDO
           MOVE FUNCTION CURRENT-DATE(1:8) TO PAY-CONTA-DT-ATUALIZACAO
           REWRITE REG-CONTA

           MOVE FUNCTION CURRENT-DATE(1:15) TO WS-ID
           MOVE WS-ID TO PAY-TRANS-ID
           MOVE WS-CONTA TO PAY-TRANS-CONTA-ORG
           MOVE ZEROS TO PAY-TRANS-CONTA-DEST
           MOVE 'PAG' TO PAY-TRANS-TIPO
           MOVE WS-VALOR TO PAY-TRANS-VALOR
           MOVE FUNCTION CURRENT-DATE(1:8) TO PAY-TRANS-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO PAY-TRANS-HORA
           MOVE WS-COD-BARRAS TO PAY-TRANS-DESCRICAO
           MOVE 'E' TO PAY-TRANS-STATUS
           MOVE 'MODPAY' TO PAY-TRANS-CANAL
           WRITE REG-TRANS

           MOVE WS-VALOR TO WS-DISP
           DISPLAY 'BOLETO PAGO: R$ ' WS-DISP
           MOVE 0 TO LS-CODIGO.

       2100-VALIDAR-CODIGO-BARRAS.
           MOVE SPACES TO WS-COD-LIMPO
           MOVE ZEROS TO WS-COD-LEN WS-SOMA
           MOVE 2 TO WS-PESO

           PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > 50
               IF WS-COD-BARRAS(WS-IDX:1) >= '0'
                  AND WS-COD-BARRAS(WS-IDX:1) <= '9'
                   ADD 1 TO WS-COD-LEN
                   IF WS-COD-LEN <= 44
                       MOVE WS-COD-BARRAS(WS-IDX:1)
                           TO WS-COD-LIMPO(WS-COD-LEN:1)
                   END-IF
               END-IF
           END-PERFORM

           IF WS-COD-LEN NOT = 44
               DISPLAY 'CODIGO DE BARRAS INVALIDO (44 DIGITOS)'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF

           PERFORM VARYING WS-IDX FROM 43 BY -1 UNTIL WS-IDX < 1
               MOVE FUNCTION NUMVAL(WS-COD-LIMPO(WS-IDX:1)) TO WS-DIG
               COMPUTE WS-SOMA = WS-SOMA + (WS-DIG * WS-PESO)
               ADD 1 TO WS-PESO
               IF WS-PESO > 9
                   MOVE 2 TO WS-PESO
               END-IF
           END-PERFORM

           COMPUTE WS-DV-CALC = 11 - FUNCTION MOD(WS-SOMA 11)
           IF WS-DV-CALC > 9
               MOVE 1 TO WS-DV-CALC
           END-IF
           MOVE FUNCTION NUMVAL(WS-COD-LIMPO(44:1)) TO WS-DV-INFORMADO

           IF WS-DV-CALC NOT = WS-DV-INFORMADO
               DISPLAY 'CODIGO DE BARRAS REPROVADO NO DV'
               MOVE 3 TO LS-CODIGO
           ELSE
               MOVE WS-COD-LIMPO TO WS-COD-BARRAS
               MOVE 0 TO LS-CODIGO
           END-IF.
