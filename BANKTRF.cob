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

           SELECT ARQPIX ASSIGN TO 'BANKPIX.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS PIX-REC-CHAVE
               FILE STATUS IS FS-PIX.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

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

       FD  ARQPIX.
       01  REG-PIX.
           05  PIX-REC-CHAVE         PIC X(36).
           05  PIX-REC-CONTA         PIC 9(10).
           05  PIX-REC-STATUS        PIC X(1).

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       01  WS-CTRL.
           05  FS-CONTAS             PIC XX.
               88  FS-OK             VALUE '00'.
               88  FS-EOF            VALUE '10'.
               88  FS-NFD            VALUE '23'.
           05  FS-TRANS              PIC XX.
               88  FS-OK-TRANS       VALUE '00'.
           05  FS-PIX                PIC XX.
               88  FS-PIX-OK         VALUE '00'.
               88  FS-PIX-DUP        VALUE '22'.
               88  FS-PIX-NFD        VALUE '23'.
           05  FS-BRIDGE             PIC XX.
               88  FS-BRIDGE-OK      VALUE '00'.
               88  FS-BRIDGE-EOF     VALUE '10'.

       01  WS-BRIDGE.
           05  WS-BR-OUTFILE          PIC X(40).
           05  WS-BR-CMD              PIC X(250).
           05  WS-BR-VALOR-INT-N      PIC 9(11).
           05  WS-BR-VALOR-INT-E      PIC Z(10)9.
           05  WS-BR-VALOR-DEC        PIC 99.
           05  WS-BR-VALOR-STR        PIC X(20).
           05  WS-BR-ORG-E            PIC Z(9)9.
           05  WS-BR-DES-E            PIC Z(9)9.
           05  WS-BR-LINE             PIC X(200).
           05  WS-BR-KEY              PIC X(30).
           05  WS-BR-VAL              PIC X(160).
           05  WS-BR-OK               PIC 9 VALUE 0.
           05  WS-BR-TRANS-ID         PIC 9(15) VALUE 0.
           05  WS-BR-ERROR            PIC X(150) VALUE SPACES.
           05  WS-BR-SALDO-STR        PIC X(30).
           05  WS-BR-SALDO-NOVO       PIC S9(13)V99 COMP-3.
           05  WS-BR-SYNC-CONTA-N     PIC 9(10).
           05  WS-BR-SYNC-CONTA-E     PIC Z(9)9.
           05  WS-BR-TAXA-INT-N       PIC 9(5).
           05  WS-BR-TAXA-INT-E       PIC Z(4)9.
           05  WS-BR-TAXA-DEC         PIC 99.
           05  WS-BR-TAXA-STR         PIC X(10).

       01  WS-PIX-GEN.
           05  WS-PIX-SEED           PIC 9(8).
           05  WS-PIX-RN1            PIC 9(9).
           05  WS-PIX-RN2            PIC 9(9).
           05  WS-PIX-RN1X           PIC X(9).
           05  WS-PIX-RN2X           PIC X(9).
           05  WS-PIX-TS             PIC X(14).
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

       01  WS-ID-CTRL.
           05  WS-ID-BASE-DT         PIC 9(8).
           05  WS-ID-BASE-HR         PIC 9(6).
           05  WS-ID-SEQ             PIC 9(1) VALUE 0.

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
           OPEN I-O ARQPIX
           IF NOT FS-PIX-OK
               OPEN OUTPUT ARQPIX
               CLOSE ARQPIX
               OPEN I-O ARQPIX
           END-IF
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-ID-BASE-DT
           MOVE FUNCTION CURRENT-DATE(9:6) TO WS-ID-BASE-HR
           COMPUTE WS-ID =
               FUNCTION NUMVAL(WS-ID-BASE-DT) * 10000000 +
               FUNCTION NUMVAL(WS-ID-BASE-HR) * 10
           PERFORM 1000-MENU UNTIL PARAR
           CLOSE ARQCONTAS ARQTRANS ARQPIX
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU.
           DISPLAY '----------------------------------------'
           DISPLAY ' TRANSFERENCIAS'
           DISPLAY '----------------------------------------'
           DISPLAY ' 01. TED (taxa R$ 14,90)'
           DISPLAY ' 02. DOC (taxa R$ 5,80)'
           DISPLAY ' 03. PIX (taxa R$ 0,00)'
           DISPLAY ' 04. Cadastrar Chave PIX Aleatoria'
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
               WHEN '04'
                   PERFORM 2800-CADASTRAR-CHAVE-PIX
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

           PERFORM 2350-CHAMAR-RAZAO
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
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
           ADD 1 TO WS-ID-SEQ
           IF WS-ID-SEQ > 9
               MOVE 0 TO WS-ID-SEQ
           END-IF
           COMPUTE WS-ID = WS-ID + 1
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
           IF WS-PIX-TIPO = 'A'
               MOVE WS-PIX-CHAVE TO PIX-REC-CHAVE
               READ ARQPIX KEY IS PIX-REC-CHAVE
               IF FS-PIX-OK AND PIX-REC-STATUS = 'A'
                   MOVE PIX-REC-CONTA TO TRF-CONTA-NUM
                   READ ARQCONTAS KEY IS TRF-CONTA-NUM
                   IF FS-OK
                       MOVE 'S' TO WS-ACHOU-DEST
                       MOVE REG-CONTA TO WS-DES-BUF
                       MOVE TRF-CONTA-NUM TO WS-DES-NUM
                       MOVE TRF-CONTA-SALDO TO WS-DES-SALDO
                   END-IF
               END-IF
           END-IF
           IF WS-ACHOU-DEST = 'S'
               GO TO 2600-VALIDAR-DESTINO
           END-IF
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
           END-IF.

       2600-VALIDAR-DESTINO.
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
           DISPLAY 'Tipo de chave PIX (C=CPF E=Email T=Tel A=Aleat): '
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

           MOVE ZEROS TO WS-TAXA
           PERFORM 2350-CHAMAR-RAZAO
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           PERFORM 2500-GRAVAR-TRANS

           MOVE WS-VALOR TO WS-VAL-DISP
           DISPLAY 'PIX EFETUADO: R$ ' WS-VAL-DISP
           MOVE 0 TO LS-CODIGO.

       2350-CHAMAR-RAZAO.
           COMPUTE WS-BR-VALOR-INT-N = FUNCTION INTEGER-PART(WS-VALOR)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER((WS-VALOR - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR

           COMPUTE WS-BR-TAXA-INT-N = FUNCTION INTEGER-PART(WS-TAXA)
           COMPUTE WS-BR-TAXA-DEC =
               FUNCTION INTEGER((WS-TAXA - WS-BR-TAXA-INT-N) * 100)
           MOVE WS-BR-TAXA-INT-N TO WS-BR-TAXA-INT-E
           MOVE SPACES TO WS-BR-TAXA-STR
           STRING FUNCTION TRIM(WS-BR-TAXA-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-TAXA-DEC DELIMITED SIZE
                  INTO WS-BR-TAXA-STR

           MOVE WS-ORG-NUM TO WS-BR-ORG-E
           MOVE WS-DES-NUM TO WS-BR-DES-E

           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMP-' WS-ID '.OUT' DELIMITED SIZE
               INTO WS-BR-OUTFILE

           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py transfer '
                  FUNCTION TRIM(WS-BR-ORG-E) ' '
                  FUNCTION TRIM(WS-BR-DES-E) ' '
                  FUNCTION TRIM(WS-BR-VALOR-STR) ' '
                  WS-ID
                  ' --fee ' FUNCTION TRIM(WS-BR-TAXA-STR)
                  ' --cobol-out ' FUNCTION TRIM(WS-BR-OUTFILE)
                  DELIMITED SIZE INTO WS-BR-CMD

           CALL 'SYSTEM' USING WS-BR-CMD
           PERFORM 2360-LER-RESULTADO-BRIDGE

           EVALUATE TRUE
               WHEN RETURN-CODE = 0 AND WS-BR-OK = 1
                   MOVE 0 TO LS-CODIGO
                   PERFORM 2900-SINCRONIZAR-SALDO
               WHEN RETURN-CODE = 2
                   DISPLAY 'RAZAO REJEITOU A OPERACAO: ' WS-BR-ERROR
                   MOVE 9998 TO LS-CODIGO
               WHEN RETURN-CODE = 3
                   DISPLAY 'RAZAO NEGOU AUTORIZACAO: ' WS-BR-ERROR
                   MOVE 9997 TO LS-CODIGO
               WHEN OTHER
                   DISPLAY 'ERRO FATAL NA CHAMADA AO RAZAO ('
                       RETURN-CODE '): ' WS-BR-ERROR
                   MOVE 9999 TO LS-CODIGO
           END-EVALUATE.

       2360-LER-RESULTADO-BRIDGE.
           MOVE 0 TO WS-BR-OK
           MOVE 0 TO WS-BR-TRANS-ID
           MOVE SPACES TO WS-BR-ERROR
           OPEN INPUT ARQBRIDGE
           IF FS-BRIDGE-OK
               PERFORM UNTIL FS-BRIDGE-EOF
                   READ ARQBRIDGE INTO WS-BR-LINE
                   IF NOT FS-BRIDGE-EOF
                       PERFORM 2370-PROCESSAR-LINHA-BRIDGE
                   END-IF
               END-PERFORM
               CLOSE ARQBRIDGE
           END-IF.

       2370-PROCESSAR-LINHA-BRIDGE.
           MOVE SPACES TO WS-BR-KEY WS-BR-VAL
           UNSTRING WS-BR-LINE DELIMITED BY '='
               INTO WS-BR-KEY WS-BR-VAL
           EVALUATE FUNCTION TRIM(WS-BR-KEY)
               WHEN 'OK'
                   IF FUNCTION TRIM(WS-BR-VAL) = '1'
                       MOVE 1 TO WS-BR-OK
                   END-IF
               WHEN 'TRANSACTION_ID'
                   IF WS-BR-VAL NOT = SPACES
                       MOVE FUNCTION NUMVAL(FUNCTION TRIM(WS-BR-VAL))
                           TO WS-BR-TRANS-ID
                   END-IF
               WHEN 'ERROR'
                   MOVE FUNCTION TRIM(WS-BR-VAL) TO WS-BR-ERROR
               WHEN OTHER
                   CONTINUE
           END-EVALUATE.

       2900-SINCRONIZAR-SALDO.
           MOVE WS-ORG-NUM TO WS-BR-SYNC-CONTA-N
           PERFORM 2910-BUSCAR-SALDO-RAZAO
           IF WS-BR-OK = 1
               MOVE WS-ORG-BUF TO REG-CONTA
               MOVE WS-BR-SALDO-NOVO TO TRF-CONTA-SALDO
               MOVE FUNCTION CURRENT-DATE(1:8) TO
                   TRF-CONTA-DT-ATUALIZACAO
               REWRITE REG-CONTA
           END-IF

           MOVE WS-DES-NUM TO WS-BR-SYNC-CONTA-N
           PERFORM 2910-BUSCAR-SALDO-RAZAO
           IF WS-BR-OK = 1
               MOVE WS-DES-BUF TO REG-CONTA
               MOVE WS-BR-SALDO-NOVO TO TRF-CONTA-SALDO
               MOVE FUNCTION CURRENT-DATE(1:8) TO
                   TRF-CONTA-DT-ATUALIZACAO
               REWRITE REG-CONTA
           END-IF.

       2910-BUSCAR-SALDO-RAZAO.
           MOVE WS-BR-SYNC-CONTA-N TO WS-BR-SYNC-CONTA-E
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPS-' WS-BR-SYNC-CONTA-N '.OUT' DELIMITED SIZE
               INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py account '
                  FUNCTION TRIM(WS-BR-SYNC-CONTA-E)
                  ' --cobol-out ' FUNCTION TRIM(WS-BR-OUTFILE)
                  DELIMITED SIZE INTO WS-BR-CMD
           CALL 'SYSTEM' USING WS-BR-CMD
           MOVE 0 TO WS-BR-OK
           IF RETURN-CODE = 0
               MOVE SPACES TO WS-BR-SALDO-STR
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
                               COMPUTE WS-BR-SALDO-NOVO =
                                   FUNCTION NUMVAL(WS-BR-SALDO-STR)
                               MOVE 1 TO WS-BR-OK
                           END-IF
                       END-IF
                   END-PERFORM
                   CLOSE ARQBRIDGE
               END-IF
           END-IF.

       2800-CADASTRAR-CHAVE-PIX.
           DISPLAY 'Conta para cadastrar chave PIX: '
           ACCEPT WS-ORG-NUM
           PERFORM 2100-LER-ORIGEM
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           MOVE FUNCTION CURRENT-DATE(1:14) TO WS-PIX-TS
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-PIX-SEED
           COMPUTE WS-PIX-RN1 = FUNCTION INTEGER(
               FUNCTION RANDOM(WS-PIX-SEED) * 999999999)
           COMPUTE WS-PIX-RN2 = FUNCTION INTEGER(
               FUNCTION RANDOM * 999999999)
           MOVE WS-PIX-RN1 TO WS-PIX-RN1X
           MOVE WS-PIX-RN2 TO WS-PIX-RN2X
           MOVE SPACES TO PIX-REC-CHAVE
           STRING WS-PIX-TS(1:8) '-' WS-PIX-TS(9:6)
                  '-' WS-PIX-RN1X '-' WS-PIX-RN2X
                  DELIMITED SIZE INTO PIX-REC-CHAVE
           MOVE WS-ORG-NUM TO PIX-REC-CONTA
           MOVE 'A' TO PIX-REC-STATUS
           WRITE REG-PIX
           IF FS-PIX-DUP
               DISPLAY 'CHAVE JA EXISTENTE, TENTE NOVAMENTE'
               MOVE 22 TO LS-CODIGO
           ELSE IF FS-PIX-OK
               DISPLAY 'CHAVE PIX ALEATORIA CADASTRADA:'
               DISPLAY PIX-REC-CHAVE
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO AO CADASTRAR CHAVE: ' FS-PIX
               MOVE 9999 TO LS-CODIGO
           END-IF.
