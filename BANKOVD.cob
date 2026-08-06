       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKOVD.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS OVD-CONTA-NUM
               FILE STATUS IS FS-CONTAS.
           SELECT ARQOVD ASSIGN TO 'BANKOVD.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS OVD-HIST-ID
               FILE STATUS IS FS-OVD.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONTAS.
       01  REG-CONTA.
           05  OVD-CONTA-NUM         PIC 9(10).
           05  OVD-CONTA-AGENCIA     PIC 9(4).
           05  OVD-CONTA-DIGITO      PIC 9(1).
           05  OVD-CONTA-TIPO        PIC X(2).
           05  OVD-CONTA-STATUS      PIC X(1).
           05  OVD-CONTA-SALDO       PIC S9(13)V99 COMP-3.
           05  OVD-CONTA-LIMITE      PIC S9(11)V99 COMP-3.
           05  OVD-CONTA-TITULAR     PIC X(60).
           05  OVD-CONTA-CPF         PIC X(11).
           05  FILLER                PIC X(168).

       FD  ARQOVD.
       01  REG-OVD.
           05  OVD-HIST-ID           PIC 9(15).
           05  OVD-HIST-CONTA        PIC 9(10).
           05  OVD-HIST-TIPO         PIC X(1).
           05  OVD-HIST-VALOR        PIC S9(11)V99 COMP-3.
           05  OVD-HIST-SALDO_ANT    PIC S9(13)V99 COMP-3.
           05  OVD-HIST-SALDO_NOV    PIC S9(13)V99 COMP-3.
           05  OVD-HIST-JUROS        PIC S9(9)V99 COMP-3.
           05  OVD-HIST-DATA         PIC 9(8).

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-OVD-CTRL.
           05  FS-CONTAS             PIC XX.
               88  FS-CT-OK          VALUE '00'.
               88  FS-CT-NFD         VALUE '23'.
           05  FS-OVD                PIC XX.
               88  FS-OVD-OK         VALUE '00'.
               88  FS-OVD-EOF        VALUE '10'.
           05  FS-BRIDGE             PIC XX.
               88  FS-BRIDGE-OK      VALUE '00'.
               88  FS-BRIDGE-EOF     VALUE '10'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  OVD-PARAR         VALUE 'N'.
           05  WS-OVD-SEQ            PIC 9(15) VALUE ZEROS.

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

       01  WS-OVD-CALC.
           05  WS-OVD-CONTA-NUM      PIC 9(10).
           05  WS-OVD-VALOR          PIC S9(11)V99 COMP-3.
           05  WS-OVD-DISPONIVEL     PIC S9(13)V99 COMP-3.
           05  WS-OVD-USO            PIC S9(11)V99 COMP-3.
           05  WS-OVD-JUROS-MES      PIC 9(3)V99 COMP-3 VALUE 12,75.
           05  WS-OVD-JUROS_CALC     PIC S9(9)V99 COMP-3.
           05  WS-OVD-IOF            PIC S9(7)V99 COMP-3.
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQCONTAS
           OPEN I-O ARQOVD
           IF NOT FS-OVD-OK
               OPEN OUTPUT ARQOVD
               CLOSE ARQOVD
               OPEN I-O ARQOVD
           END-IF
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-OVD-SEQ
           COMPUTE WS-OVD-SEQ =
               FUNCTION NUMVAL(WS-OVD-SEQ) * 10000000
           PERFORM 1000-MENU UNTIL OVD-PARAR
           CLOSE ARQCONTAS ARQOVD
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU SECTION.
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '   CHEQUE ESPECIAL / CREDITO ROTATIVO'
           DISPLAY '========================================'
           DISPLAY ' 01. Consultar Saldo e Limite'
           DISPLAY ' 02. Usar Credito Rotativo'
           DISPLAY ' 03. Pagar/Reduzir Saldo Devedor'
           DISPLAY ' 04. Extrato Cheque Especial'
           DISPLAY ' 05. Simulacao de Juros'
           DISPLAY ' 06. Solicitar Aumento de Limite'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-CONSULTAR
               WHEN '02' PERFORM 3000-USAR-CREDITO
               WHEN '03' PERFORM 4000-PAGAR
               WHEN '04' PERFORM 5000-EXTRATO
               WHEN '05' PERFORM 6000-SIMULAR-JUROS
               WHEN '06' PERFORM 7000-SOLICITAR-AUMENTO
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-CONSULTAR SECTION.
       2000-INICIO.
           DISPLAY 'Numero da conta: '
           ACCEPT WS-OVD-CONTA-NUM
           MOVE WS-OVD-CONTA-NUM TO OVD-CONTA-NUM
           READ ARQCONTAS KEY IS OVD-CONTA-NUM
           IF FS-CT-NFD
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           COMPUTE WS-OVD-DISPONIVEL =
               OVD-CONTA-SALDO + OVD-CONTA-LIMITE
           DISPLAY '========================================'
           DISPLAY ' Titular: ' OVD-CONTA-TITULAR(1:40)
           MOVE OVD-CONTA-SALDO TO WS-DIS
           DISPLAY ' Saldo conta:      R$ ' WS-DIS
           MOVE OVD-CONTA-LIMITE TO WS-DIS
           DISPLAY ' Limite chq esp:   R$ ' WS-DIS
           MOVE WS-OVD-DISPONIVEL TO WS-DIS
           DISPLAY ' Total disponivel: R$ ' WS-DIS
           IF OVD-CONTA-SALDO < ZEROS
               MOVE OVD-CONTA-SALDO TO WS-OVD-USO
               COMPUTE WS-OVD-USO = WS-OVD-USO * -1
               MOVE WS-OVD-USO TO WS-DIS
               DISPLAY ' LIMITE EM USO:    R$ ' WS-DIS
               DISPLAY ' Taxa: ' WS-OVD-JUROS-MES '% a.m.'
           END-IF
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       3000-USAR-CREDITO SECTION.
       3000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-OVD-CONTA-NUM
           MOVE WS-OVD-CONTA-NUM TO OVD-CONTA-NUM
           READ ARQCONTAS KEY IS OVD-CONTA-NUM
           IF FS-CT-NFD
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           COMPUTE WS-OVD-DISPONIVEL =
               OVD-CONTA-SALDO + OVD-CONTA-LIMITE
           IF WS-OVD-DISPONIVEL <= ZEROS
               DISPLAY 'LIMITE ESGOTADO'
               MOVE 1 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE WS-OVD-DISPONIVEL TO WS-DIS
           DISPLAY 'Disponivel: R$ ' WS-DIS
           DISPLAY 'Valor a utilizar: '
           ACCEPT WS-OVD-VALOR
           IF WS-OVD-VALOR > WS-OVD-DISPONIVEL
               DISPLAY 'VALOR EXCEDE O DISPONIVEL'
               MOVE 3 TO LS-CODIGO
               EXIT SECTION
           END-IF
           COMPUTE WS-OVD-JUROS_CALC ROUNDED =
               WS-OVD-VALOR * WS-OVD-JUROS-MES / 100
           COMPUTE WS-OVD-IOF ROUNDED =
               WS-OVD-VALOR * 0,0038
           MOVE WS-OVD-JUROS_CALC TO WS-DIS
           DISPLAY 'Juros previstos (' WS-OVD-JUROS-MES '%a.m.): R$ '
                   WS-DIS
           MOVE WS-OVD-IOF TO WS-DIS
           DISPLAY 'IOF: R$ ' WS-DIS
           DISPLAY 'Confirmar uso do credito? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               PERFORM 3050-DEBITAR-RAZAO
               IF WS-BR-OK NOT = 1
                   DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
                   MOVE 9998 TO LS-CODIGO
                   EXIT SECTION
               END-IF
               MOVE OVD-CONTA-SALDO TO OVD-HIST-SALDO_ANT
               SUBTRACT WS-OVD-VALOR FROM OVD-CONTA-SALDO
               MOVE OVD-CONTA-SALDO TO OVD-HIST-SALDO_NOV
               REWRITE REG-CONTA
               ADD 1 TO WS-OVD-SEQ
               MOVE WS-OVD-SEQ TO OVD-HIST-ID
               MOVE WS-OVD-CONTA-NUM TO OVD-HIST-CONTA
               MOVE 'U' TO OVD-HIST-TIPO
               MOVE WS-OVD-VALOR TO OVD-HIST-VALOR
               MOVE WS-OVD-JUROS_CALC TO OVD-HIST-JUROS
               MOVE FUNCTION CURRENT-DATE(1:8) TO OVD-HIST-DATA
               WRITE REG-OVD
               MOVE WS-OVD-VALOR TO WS-DIS
               DISPLAY 'CREDITO UTILIZADO: R$ ' WS-DIS
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CANCELADO'
           END-IF.

       3050-DEBITAR-RAZAO.
           MOVE WS-OVD-CONTA-NUM TO WS-BR-CONTA-E
           MOVE WS-OVD-SEQ TO WS-BR-ID-E
           COMPUTE WS-BR-VALOR-INT-N =
               FUNCTION INTEGER-PART(WS-OVD-VALOR)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER(
                   (WS-OVD-VALOR - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPW-' FUNCTION CURRENT-DATE(1:15) '.OUT'
                  DELIMITED SIZE INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle OVD '
                  'OVERDRAFT_DRAW '
                  FUNCTION TRIM(WS-BR-CONTA-E) ' '
                  FUNCTION TRIM(WS-BR-VALOR-STR) ' '
                  FUNCTION CURRENT-DATE(1:15) '-'
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

       4000-PAGAR SECTION.
       4000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-OVD-CONTA-NUM
           MOVE WS-OVD-CONTA-NUM TO OVD-CONTA-NUM
           READ ARQCONTAS KEY IS OVD-CONTA-NUM
           IF FS-CT-NFD
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF OVD-CONTA-SALDO >= ZEROS
               DISPLAY 'CONTA SEM SALDO DEVEDOR NO CHEQUE ESPECIAL'
               MOVE 0 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE OVD-CONTA-SALDO TO WS-OVD-USO
           COMPUTE WS-OVD-USO = WS-OVD-USO * -1
           MOVE WS-OVD-USO TO WS-DIS
           DISPLAY 'Saldo devedor: R$ ' WS-DIS
           DISPLAY 'Valor do pagamento: '
           ACCEPT WS-OVD-VALOR
           PERFORM 4050-CREDITAR-RAZAO
           IF WS-BR-OK NOT = 1
               DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
               MOVE 9998 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE OVD-CONTA-SALDO TO OVD-HIST-SALDO_ANT
           ADD WS-OVD-VALOR TO OVD-CONTA-SALDO
           MOVE OVD-CONTA-SALDO TO OVD-HIST-SALDO_NOV
           REWRITE REG-CONTA
           ADD 1 TO WS-OVD-SEQ
           MOVE WS-OVD-SEQ TO OVD-HIST-ID
           MOVE WS-OVD-CONTA-NUM TO OVD-HIST-CONTA
           MOVE 'P' TO OVD-HIST-TIPO
           MOVE WS-OVD-VALOR TO OVD-HIST-VALOR
           MOVE ZEROS TO OVD-HIST-JUROS
           MOVE FUNCTION CURRENT-DATE(1:8) TO OVD-HIST-DATA
           WRITE REG-OVD
           DISPLAY 'PAGAMENTO REALIZADO!'
           MOVE OVD-CONTA-SALDO TO WS-DIS
           DISPLAY 'Novo saldo: R$ ' WS-DIS
           MOVE 0 TO LS-CODIGO.

       4050-CREDITAR-RAZAO.
           MOVE WS-OVD-CONTA-NUM TO WS-BR-CONTA-E
           MOVE WS-OVD-SEQ TO WS-BR-ID-E
           COMPUTE WS-BR-VALOR-INT-N =
               FUNCTION INTEGER-PART(WS-OVD-VALOR)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER(
                   (WS-OVD-VALOR - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPV-' FUNCTION CURRENT-DATE(1:15) '.OUT'
                  DELIMITED SIZE INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle OVD OVERDRAFT '
                  FUNCTION TRIM(WS-BR-CONTA-E) ' '
                  FUNCTION TRIM(WS-BR-VALOR-STR) ' '
                  FUNCTION CURRENT-DATE(1:15) '-'
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

       5000-EXTRATO SECTION.
       5000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-OVD-CONTA-NUM
           DISPLAY '========================================'
           DISPLAY ' EXTRATO CHEQUE ESPECIAL'
           DISPLAY ' Data      Tipo  Valor         Juros'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO OVD-HIST-ID
           START ARQOVD KEY >= OVD-HIST-ID
           PERFORM UNTIL FS-OVD-EOF
               READ ARQOVD NEXT
               IF FS-OVD-OK
                   IF OVD-HIST-CONTA = WS-OVD-CONTA-NUM
                       MOVE OVD-HIST-VALOR TO WS-DIS
                       DISPLAY OVD-HIST-DATA ' '
                               OVD-HIST-TIPO '  R$ '
                               WS-DIS
                       IF OVD-HIST-JUROS > ZEROS
                           MOVE OVD-HIST-JUROS TO WS-DIS
                           DISPLAY '  Juros: R$ ' WS-DIS
                       END-IF
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       6000-SIMULAR-JUROS SECTION.
       6000-INICIO.
           DISPLAY '--- SIMULACAO DE JUROS CHEQUE ESPECIAL ---'
           DISPLAY 'Valor utilizado (R$): '
           ACCEPT WS-OVD-VALOR
           DISPLAY 'Taxa mensal (' WS-OVD-JUROS-MES '%): confirmar?'
           ACCEPT WS-OPCAO
           COMPUTE WS-OVD-JUROS_CALC = WS-OVD-VALOR *
               WS-OVD-JUROS-MES / 100
           DISPLAY '========================================'
           MOVE WS-OVD-VALOR TO WS-DIS
           DISPLAY ' Valor utilizado:      R$ ' WS-DIS
           DISPLAY ' Taxa:                 ' WS-OVD-JUROS-MES '% a.m.'
           MOVE WS-OVD-JUROS_CALC TO WS-DIS
           DISPLAY ' Juros em 30 dias:  R$ ' WS-DIS
           COMPUTE WS-OVD-JUROS_CALC = WS-OVD-VALOR *
               ((1 + WS-OVD-JUROS-MES/100) ** 3 - 1)
           MOVE WS-OVD-JUROS_CALC TO WS-DIS
           DISPLAY ' Juros em 90 dias:  R$ ' WS-DIS
           DISPLAY ' CET anual estimado: '
           COMPUTE WS-OVD-JUROS_CALC =
               ((1 + WS-OVD-JUROS-MES/100) ** 12 - 1) * 100
           DISPLAY WS-OVD-JUROS_CALC '%'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       7000-SOLICITAR-AUMENTO SECTION.
       7000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-OVD-CONTA-NUM
           MOVE WS-OVD-CONTA-NUM TO OVD-CONTA-NUM
           READ ARQCONTAS KEY IS OVD-CONTA-NUM
           IF FS-CT-NFD
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE OVD-CONTA-LIMITE TO WS-DIS
           DISPLAY 'Limite atual: R$ ' WS-DIS
           DISPLAY 'Novo limite solicitado: '
           ACCEPT WS-OVD-VALOR
           IF WS-OVD-VALOR <= OVD-CONTA-LIMITE
               DISPLAY 'VALOR DEVE SER MAIOR QUE O ATUAL'
               MOVE 3 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE WS-OVD-VALOR TO OVD-CONTA-LIMITE
           REWRITE REG-CONTA
           MOVE WS-OVD-VALOR TO WS-DIS
           DISPLAY 'LIMITE ATUALIZADO PARA: R$ ' WS-DIS
           MOVE 0 TO LS-CODIGO.

       9999-FIM.
           EXIT PROGRAM.
