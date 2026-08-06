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

           SELECT ARQBOLETO ASSIGN TO 'BANKBOL.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS BOL-ID
               ALTERNATE RECORD KEY IS BOL-CONTA WITH DUPLICATES
               FILE STATUS IS FS-BOL.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

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

       FD  ARQBOLETO.
       01  REG-BOLETO.
           05  BOL-ID                PIC 9(10).
           05  BOL-CONTA             PIC 9(10).
           05  BOL-VALOR             PIC S9(13)V99 COMP-3.
           05  BOL-DT-EMISSAO        PIC 9(8).
           05  BOL-DT-VENCTO         PIC 9(8).
           05  BOL-BENEFICIARIO      PIC X(60).
           05  BOL-DESCRICAO         PIC X(100).
           05  BOL-COD-BARRAS        PIC X(44).
           05  BOL-STATUS            PIC X(1).
           05  BOL-FILLER            PIC X(50).

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

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       01  WS-CTRL.
           05  FS-CONTAS             PIC XX.
               88  FS-OK             VALUE '00'.
               88  FS-NFD            VALUE '23'.
           05  FS-TRANS              PIC XX.
           05  FS-BOL                PIC XX.
               88  FS-BOL-OK         VALUE '00'.
               88  FS-BOL-EOF        VALUE '10'.
               88  FS-BOL-NFD        VALUE '23'.
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
           05  WS-BR-ID-E             PIC Z(14)9.
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

       01  WS-BOL.
           05  WS-BOL-BENEFIC        PIC X(60).
           05  WS-BOL-DESCR          PIC X(100).
           05  WS-BOL-VENCTO         PIC 9(8).
           05  WS-BOL-ID-NOVO        PIC 9(10).
           05  WS-BOL-ID-SEL         PIC 9(10).
           05  WS-BOL-BARRAS         PIC X(44).
           05  WS-BOL-IDX            PIC 9(2).
           05  WS-BOL-SOMA-DV        PIC 9(9).
           05  WS-BOL-DIG            PIC 9.
           05  WS-BOL-PESO           PIC 9.
           05  WS-BOL-DV             PIC 9.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL.
           OPEN I-O ARQCONTAS ARQTRANS
           OPEN I-O ARQBOLETO
           IF FS-BOL = '35'
               OPEN OUTPUT ARQBOLETO
               CLOSE ARQBOLETO
               OPEN I-O ARQBOLETO
           END-IF
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-ID
           COMPUTE WS-BOL-ID-NOVO =
               FUNCTION NUMVAL(WS-ID) * 1000 +
               FUNCTION NUMVAL(FUNCTION CURRENT-DATE(9:3))
           PERFORM 1000-MENU UNTIL PARAR
           CLOSE ARQCONTAS ARQTRANS ARQBOLETO
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU.
           DISPLAY '----------------------------------------'
           DISPLAY ' PAGAMENTOS E BOLETOS'
           DISPLAY '----------------------------------------'
           DISPLAY ' 01. Pagar Boleto'
           DISPLAY ' 02. Emitir Boleto'
           DISPLAY ' 03. Consultar Boletos da Conta'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01'
                   PERFORM 2000-PAGAR-BOLETO
               WHEN '02'
                   PERFORM 3000-EMITIR-BOLETO
               WHEN '03'
                   PERFORM 4000-CONSULTAR-BOLETOS
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

           MOVE FUNCTION CURRENT-DATE(1:15) TO WS-ID

           PERFORM 2050-DEBITAR-RAZAO
           IF WS-BR-OK NOT = 1
               DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
               MOVE 9998 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF

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

       2050-DEBITAR-RAZAO.
           MOVE WS-CONTA TO WS-BR-CONTA-E
           MOVE WS-ID TO WS-BR-ID-E
           COMPUTE WS-BR-VALOR-INT-N = FUNCTION INTEGER-PART(WS-VALOR)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER((WS-VALOR - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPP-' WS-ID '.OUT' DELIMITED SIZE
               INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle PAY '
                  'BOLETO_PAYMENT '
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
           END-IF
           IF WS-BR-OK = 1
               PERFORM 2060-SINCRONIZAR-SALDO
           END-IF.

       2060-SINCRONIZAR-SALDO.
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPQ-' WS-ID '.OUT' DELIMITED SIZE
               INTO WS-BR-OUTFILE
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
                               MOVE WS-CONTA-BUF TO REG-CONTA
                               COMPUTE PAY-CONTA-SALDO =
                                   FUNCTION NUMVAL(WS-BR-SALDO-STR)
                               MOVE FUNCTION CURRENT-DATE(1:8) TO
                                   PAY-CONTA-DT-ATUALIZACAO
                               REWRITE REG-CONTA
                           END-IF
                       END-IF
                   END-PERFORM
                   CLOSE ARQBRIDGE
               END-IF
           END-IF.

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

       3000-EMITIR-BOLETO.
           DISPLAY 'Conta emitente: '
           ACCEPT WS-CONTA
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
           DISPLAY 'Beneficiario/Descricao: '
           ACCEPT WS-BOL-BENEFIC
           DISPLAY 'Descricao adicional: '
           ACCEPT WS-BOL-DESCR
           DISPLAY 'Valor: '
           ACCEPT WS-VALOR
           IF WS-VALOR <= ZEROS
               DISPLAY 'VALOR INVALIDO'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Vencimento (AAAAMMDD): '
           ACCEPT WS-BOL-VENCTO
           STRING '0001'                 DELIMITED SIZE
                  WS-CONTA              DELIMITED SIZE
                  INTO WS-BOL-BARRAS
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-BOL-BARRAS(15:8)
           COMPUTE WS-BOL-IDX =
               FUNCTION MOD(WS-BOL-ID-NOVO 99999999) + 1
           MOVE WS-BOL-IDX TO WS-BOL-BARRAS(23:8)
           PERFORM VARYING WS-BOL-IDX FROM 31 BY 1
                   UNTIL WS-BOL-IDX > 43
               IF WS-BOL-BARRAS(WS-BOL-IDX:1) = SPACES
                   MOVE '0' TO WS-BOL-BARRAS(WS-BOL-IDX:1)
               END-IF
           END-PERFORM
           MOVE ZEROS TO WS-BOL-SOMA-DV
           MOVE 2     TO WS-BOL-PESO
           PERFORM VARYING WS-BOL-IDX FROM 43 BY -1
                   UNTIL WS-BOL-IDX < 1
               MOVE FUNCTION NUMVAL(WS-BOL-BARRAS(WS-BOL-IDX:1))
                   TO WS-BOL-DIG
               COMPUTE WS-BOL-DIG = WS-BOL-DIG * WS-BOL-PESO
               IF WS-BOL-DIG > 9
                   SUBTRACT 9 FROM WS-BOL-DIG
               END-IF
               ADD WS-BOL-DIG TO WS-BOL-SOMA-DV
               IF WS-BOL-PESO = 2
                   MOVE 1 TO WS-BOL-PESO
               ELSE
                   MOVE 2 TO WS-BOL-PESO
               END-IF
           END-PERFORM
           COMPUTE WS-BOL-DV =
               FUNCTION MOD(10 - FUNCTION MOD(WS-BOL-SOMA-DV 10) 10)
           MOVE WS-BOL-DV TO WS-BOL-BARRAS(44:1)
           ADD 1 TO WS-BOL-ID-NOVO
           MOVE WS-BOL-ID-NOVO   TO BOL-ID
           MOVE WS-CONTA         TO BOL-CONTA
           MOVE WS-VALOR         TO BOL-VALOR
           MOVE FUNCTION CURRENT-DATE(1:8) TO BOL-DT-EMISSAO
           MOVE WS-BOL-VENCTO    TO BOL-DT-VENCTO
           MOVE WS-BOL-BENEFIC   TO BOL-BENEFICIARIO
           MOVE WS-BOL-DESCR     TO BOL-DESCRICAO
           MOVE WS-BOL-BARRAS    TO BOL-COD-BARRAS
           MOVE 'A'              TO BOL-STATUS
           WRITE REG-BOLETO
           IF NOT FS-BOL-OK
               DISPLAY 'ERRO AO GRAVAR BOLETO: ' FS-BOL
               MOVE 9 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE WS-VALOR TO WS-DISP
           DISPLAY '========================================'
           DISPLAY 'BOLETO EMITIDO COM SUCESSO'
           DISPLAY '========================================'
           DISPLAY 'ID        : ' WS-BOL-ID-NOVO
           DISPLAY 'Benefic.  : ' WS-BOL-BENEFIC
           DISPLAY 'Valor     : R$ ' WS-DISP
           DISPLAY 'Emissao   : ' FUNCTION CURRENT-DATE(1:8)
           DISPLAY 'Vencimento: ' WS-BOL-VENCTO
           DISPLAY 'Cod.Barras: ' WS-BOL-BARRAS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       4000-CONSULTAR-BOLETOS.
           DISPLAY 'Conta: '
           ACCEPT WS-CONTA
           MOVE WS-CONTA TO BOL-CONTA
           START ARQBOLETO KEY = BOL-CONTA
           IF FS-BOL-NFD
               DISPLAY 'NENHUM BOLETO ENCONTRADO'
               MOVE 0 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY '--- BOLETOS DA CONTA ' WS-CONTA ' ---'
           PERFORM UNTIL FS-BOL-EOF
               READ ARQBOLETO NEXT
               IF FS-BOL-OK
                   IF BOL-CONTA = WS-CONTA
                       MOVE BOL-VALOR TO WS-DISP
                       DISPLAY BOL-ID
                               ' | Venc: ' BOL-DT-VENCTO
                               ' | R$ '    WS-DISP
                               ' | '       BOL-STATUS
                               ' | '       BOL-BENEFICIARIO
                   ELSE
                       MOVE '10' TO FS-BOL
                   END-IF
               END-IF
           END-PERFORM
           MOVE 0 TO LS-CODIGO.
