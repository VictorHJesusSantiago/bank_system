       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKLOAN.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS LOAN-CONTA-NUM
               FILE STATUS IS FS-CONTAS.

           SELECT ARQEMPREST ASSIGN TO 'BANKEMPREST.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS EMP-ID
               ALTERNATE RECORD KEY IS EMP-CONTA WITH DUPLICATES
               FILE STATUS IS FS-EMPREST.

           SELECT ARQTRANS ASSIGN TO 'BANKTRAN.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS LOAN-TRANS-ID
               FILE STATUS IS FS-TRANS.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONTAS.
       01  REG-CONTA-LOAN.
           05  LOAN-CONTA-NUM        PIC 9(10).
           05  LOAN-CONTA-AGENCIA    PIC 9(4).
           05  LOAN-CONTA-DIGITO     PIC 9(1).
           05  LOAN-CONTA-TIPO       PIC X(2).
           05  LOAN-CONTA-STATUS     PIC X(1).
           05  LOAN-CONTA-SALDO      PIC S9(13)V99 COMP-3.
           05  LOAN-CONTA-LIMITE     PIC S9(11)V99 COMP-3.
           05  LOAN-CONTA-TITULAR    PIC X(60).
           05  LOAN-CONTA-CPF        PIC X(11).
           05  LOAN-CONTA-EMAIL      PIC X(80).
           05  LOAN-CONTA-FONE       PIC X(15).
           05  LOAN-CONTA-DT-ABER    PIC 9(8).
           05  LOAN-CONTA-DT-ATUA    PIC 9(8).
           05  LOAN-CONTA-SENHA      PIC X(64).

       FD  ARQEMPREST.
       01  REG-EMPREST.
           05  EMP-ID                PIC 9(10).
           05  EMP-CONTA             PIC 9(10).
           05  EMP-TIPO              PIC X(3).
           05  EMP-VALOR-SOLICIT     PIC S9(13)V99 COMP-3.
           05  EMP-VALOR-PARCEL      PIC S9(13)V99 COMP-3.
           05  EMP-TAXA-MENSAL       PIC S9(3)V9(6) COMP-3.
           05  EMP-PARCELAS-TOT      PIC 9(3).
           05  EMP-PARCELAS-PG       PIC 9(3).
           05  EMP-DT-CONTRATO       PIC 9(8).
           05  EMP-DT-VENCTO         PIC 9(8).
           05  EMP-SALDO-DEVEDOR     PIC S9(13)V99 COMP-3.
           05  EMP-STATUS            PIC X(1).

       FD  ARQTRANS.
       01  REG-TRANS-LOAN.
           05  LOAN-TRANS-ID         PIC 9(15).
           05  LOAN-TRANS-ORIG       PIC 9(10).
           05  LOAN-TRANS-DEST       PIC 9(10).
           05  LOAN-TRANS-TIPO       PIC X(3).
           05  LOAN-TRANS-VALOR      PIC S9(13)V99 COMP-3.
           05  LOAN-TRANS-DATA       PIC 9(8).
           05  LOAN-TRANS-HORA       PIC 9(6).
           05  LOAN-TRANS-DESCR      PIC X(100).
           05  LOAN-TRANS-STATUS     PIC X(1).
           05  LOAN-TRANS-NSU        PIC 9(12).
           05  LOAN-TRANS-CANAL      PIC X(10).

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       01  WS-CTRL.
           05  FS-CONTAS             PIC XX.
               88  FS-OK-CONTAS      VALUE '00'.
               88  FS-NFD-CONTA      VALUE '23'.
           05  FS-EMPREST            PIC XX.
               88  FS-OK-EMP         VALUE '00'.
               88  FS-EOF-EMP        VALUE '10'.
               88  FS-NFD-EMP        VALUE '23'.
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
           05  WS-BR-ID-STR           PIC X(21).
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

       01  WS-DADOS.
           05  WS-CONTA-NUM          PIC 9(10).
           05  WS-CONTA-SALDO        PIC S9(13)V99 COMP-3.
           05  WS-CONTA-LIMITE       PIC S9(11)V99 COMP-3.
           05  WS-CONTA-STATUS       PIC X(1).
           05  WS-CONTA-BUF          PIC X(295).
           05  WS-EMP-TIPO-SEL       PIC X(3).
           05  WS-VALOR-SOL          PIC S9(13)V99 COMP-3.
           05  WS-PARCELAS           PIC 9(3).
           05  WS-TAXA               PIC S9(3)V9(6) COMP-3.
           05  WS-PMT                PIC S9(13)V99 COMP-3.
           05  WS-TOTAL-PAGAR        PIC S9(13)V99 COMP-3.
           05  WS-SALDO-DEV          PIC S9(13)V99 COMP-3.
           05  WS-EMP-ID-SEL         PIC 9(10).

       01  WS-CALC.
           05  WS-TAXA-1             PIC S9(3)V9(8) COMP-3.
           05  WS-POW-N              PIC S9(13)V9(6) COMP-3.
           05  WS-IDX                PIC 9(3).
           05  WS-PARCELA-EXIB       PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-PARCELA-NUM-EXIB   PIC ZZ9.
           05  WS-VALOR-EXIB         PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-TOTAL-EXIB         PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-SALDO-EXIB         PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-TAXA-EXIB          PIC Z9,9999.

       01  WS-ID-CTRL.
           05  WS-ID-DT              PIC 9(8).
           05  WS-ID-HR              PIC 9(6).
           05  WS-PROXIMO-ID         PIC 9(10).
           05  WS-TRANS-ID           PIC 9(15).

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL.
           OPEN I-O ARQCONTAS ARQTRANS
           OPEN I-O ARQEMPREST
           IF FS-EMPREST = '35'
               OPEN OUTPUT ARQEMPREST
               CLOSE ARQEMPREST
               OPEN I-O ARQEMPREST
           END-IF
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-ID-DT
           MOVE FUNCTION CURRENT-DATE(9:6) TO WS-ID-HR
           COMPUTE WS-TRANS-ID =
               FUNCTION NUMVAL(WS-ID-DT) * 10000000 +
               FUNCTION NUMVAL(WS-ID-HR) * 10
           COMPUTE WS-PROXIMO-ID =
               FUNCTION NUMVAL(WS-ID-DT) * 100 +
               FUNCTION NUMVAL(WS-ID-HR(1:4))
           PERFORM 1000-MENU UNTIL PARAR
           CLOSE ARQCONTAS ARQTRANS ARQEMPREST
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU.
           DISPLAY '----------------------------------------'
           DISPLAY ' EMPRESTIMOS E FINANCIAMENTOS'
           DISPLAY '----------------------------------------'
           DISPLAY ' 01. Solicitar Emprestimo'
           DISPLAY ' 02. Consultar Emprestimo'
           DISPLAY ' 03. Pagar Parcela'
           DISPLAY ' 04. Simular Emprestimo'
           DISPLAY ' 05. Listar por Conta'
           DISPLAY ' 06. Quitacao Antecipada'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01'  PERFORM 2000-SOLICITAR
               WHEN '02'  PERFORM 3000-CONSULTAR
               WHEN '03'  PERFORM 4000-PAGAR-PARCELA
               WHEN '04'  PERFORM 5000-SIMULAR
               WHEN '05'  PERFORM 6000-LISTAR
               WHEN '06'  PERFORM 7000-QUITAR
               WHEN '00'  MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-SOLICITAR.
           DISPLAY 'Conta: '
           ACCEPT WS-CONTA-NUM
           PERFORM 2100-BUSCAR-CONTA
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Tipo (PES=Pessoal CON=Consignado'
                   ' IMO=Imobiliario VEI=Veiculo): '
           ACCEPT WS-EMP-TIPO-SEL
           PERFORM 2200-DEFINIR-TAXA
           DISPLAY 'Valor solicitado: '
           ACCEPT WS-VALOR-SOL
           IF WS-VALOR-SOL <= ZEROS
               DISPLAY 'VALOR INVALIDO'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Numero de parcelas (1-360): '
           ACCEPT WS-PARCELAS
           IF WS-PARCELAS <= 0 OR WS-PARCELAS > 360
               DISPLAY 'PARCELAS INVALIDAS (1-360)'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           PERFORM 2300-CALCULAR-PMT
           MOVE WS-PMT        TO WS-PARCELA-EXIB
           MOVE WS-VALOR-SOL  TO WS-VALOR-EXIB
           MOVE WS-TOTAL-PAGAR TO WS-TOTAL-EXIB
           DISPLAY 'Valor solicitado : R$ ' WS-VALOR-EXIB
           DISPLAY 'Parcela mensal   : R$ ' WS-PARCELA-EXIB
           DISPLAY 'Total a pagar    : R$ ' WS-TOTAL-EXIB
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO(1:1) NOT = 'S'
               DISPLAY 'OPERACAO CANCELADA'
               MOVE 0 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           PERFORM 2400-CREDITAR-CONTA
           IF LS-CODIGO = 0
               PERFORM 2500-GRAVAR-EMPRESTIMO
           END-IF
           IF LS-CODIGO = 0
               DISPLAY 'EMPRESTIMO APROVADO - ID: ' WS-PROXIMO-ID
               DISPLAY 'Valor creditado na conta'
           END-IF.

       2100-BUSCAR-CONTA.
           MOVE WS-CONTA-NUM TO LOAN-CONTA-NUM
           READ ARQCONTAS KEY IS LOAN-CONTA-NUM
           IF FS-NFD-CONTA
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
           ELSE
               MOVE REG-CONTA-LOAN   TO WS-CONTA-BUF
               MOVE LOAN-CONTA-SALDO  TO WS-CONTA-SALDO
               MOVE LOAN-CONTA-LIMITE TO WS-CONTA-LIMITE
               MOVE LOAN-CONTA-STATUS TO WS-CONTA-STATUS
               IF WS-CONTA-STATUS NOT = 'A'
                   DISPLAY 'CONTA INATIVA'
                   MOVE 4 TO LS-CODIGO
               ELSE
                   MOVE 0 TO LS-CODIGO
               END-IF
           END-IF.

       2200-DEFINIR-TAXA.
           EVALUATE WS-EMP-TIPO-SEL
               WHEN 'PES'
                   MOVE 0,019900 TO WS-TAXA
               WHEN 'CON'
                   MOVE 0,014900 TO WS-TAXA
               WHEN 'IMO'
                   MOVE 0,007900 TO WS-TAXA
               WHEN 'VEI'
                   MOVE 0,016900 TO WS-TAXA
               WHEN OTHER
                   MOVE 'PES'    TO WS-EMP-TIPO-SEL
                   MOVE 0,019900 TO WS-TAXA
           END-EVALUATE
           MOVE WS-TAXA TO WS-TAXA-EXIB
           DISPLAY 'Taxa mensal: ' WS-TAXA-EXIB '%'.

       2300-CALCULAR-PMT.
           COMPUTE WS-TAXA-1 = 1 + WS-TAXA
           MOVE 1 TO WS-POW-N
           PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-PARCELAS
               COMPUTE WS-POW-N = WS-POW-N * WS-TAXA-1
           END-PERFORM
           COMPUTE WS-PMT ROUNDED =
               WS-VALOR-SOL * (WS-TAXA * WS-POW-N)
               / (WS-POW-N - 1)
           COMPUTE WS-TOTAL-PAGAR = WS-PMT * WS-PARCELAS.

       2400-CREDITAR-CONTA.
           MOVE WS-CONTA-BUF TO REG-CONTA-LOAN
           ADD WS-VALOR-SOL TO LOAN-CONTA-SALDO
           MOVE FUNCTION CURRENT-DATE(1:8) TO LOAN-CONTA-DT-ATUA
           REWRITE REG-CONTA-LOAN
           IF NOT FS-OK-CONTAS
               DISPLAY 'ERRO AO CREDITAR: ' FS-CONTAS
               MOVE 9 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-TRANS-ID
           MOVE WS-TRANS-ID    TO LOAN-TRANS-ID
           MOVE WS-CONTA-NUM   TO LOAN-TRANS-ORIG
           MOVE ZEROS          TO LOAN-TRANS-DEST
           MOVE 'EMP'          TO LOAN-TRANS-TIPO
           MOVE WS-VALOR-SOL   TO LOAN-TRANS-VALOR
           MOVE FUNCTION CURRENT-DATE(1:8) TO LOAN-TRANS-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO LOAN-TRANS-HORA
           MOVE 'Credito de emprestimo' TO LOAN-TRANS-DESCR
           MOVE 'E'            TO LOAN-TRANS-STATUS
           MOVE ZEROS          TO LOAN-TRANS-NSU
           MOVE 'MODLOAN'      TO LOAN-TRANS-CANAL
           WRITE REG-TRANS-LOAN
           IF FS-OK-TRANS
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO TRANS: ' FS-TRANS
               MOVE 9 TO LS-CODIGO
           END-IF.

       2500-GRAVAR-EMPRESTIMO.
           ADD 1 TO WS-PROXIMO-ID
           MOVE WS-PROXIMO-ID    TO EMP-ID
           MOVE WS-CONTA-NUM     TO EMP-CONTA
           MOVE WS-EMP-TIPO-SEL  TO EMP-TIPO
           MOVE WS-VALOR-SOL     TO EMP-VALOR-SOLICIT
           MOVE WS-PMT           TO EMP-VALOR-PARCEL
           MOVE WS-TAXA          TO EMP-TAXA-MENSAL
           MOVE WS-PARCELAS      TO EMP-PARCELAS-TOT
           MOVE ZEROS            TO EMP-PARCELAS-PG
           MOVE FUNCTION CURRENT-DATE(1:8) TO EMP-DT-CONTRATO
           MOVE FUNCTION CURRENT-DATE(1:8) TO EMP-DT-VENCTO
           MOVE WS-TOTAL-PAGAR   TO EMP-SALDO-DEVEDOR
           MOVE 'A'              TO EMP-STATUS
           WRITE REG-EMPREST
           IF FS-OK-EMP
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO GRAVAR EMP: ' FS-EMPREST
               MOVE 9 TO LS-CODIGO
           END-IF.

       3000-CONSULTAR.
           DISPLAY 'ID do Emprestimo: '
           ACCEPT WS-EMP-ID-SEL
           MOVE WS-EMP-ID-SEL TO EMP-ID
           READ ARQEMPREST KEY IS EMP-ID
           IF FS-NFD-EMP
               DISPLAY 'EMPRESTIMO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
           ELSE
               MOVE EMP-VALOR-PARCEL  TO WS-PARCELA-EXIB
               MOVE EMP-SALDO-DEVEDOR TO WS-SALDO-EXIB
               MOVE EMP-VALOR-SOLICIT TO WS-VALOR-EXIB
               DISPLAY '--- EMPRESTIMO ' EMP-ID ' ---'
               DISPLAY 'Conta       : ' EMP-CONTA
               DISPLAY 'Tipo        : ' EMP-TIPO
               DISPLAY 'Valor orig  : R$ ' WS-VALOR-EXIB
               DISPLAY 'Parcela     : R$ ' WS-PARCELA-EXIB
               DISPLAY 'Parcelas    : ' EMP-PARCELAS-PG
                       '/' EMP-PARCELAS-TOT
               DISPLAY 'Saldo dev   : R$ ' WS-SALDO-EXIB
               DISPLAY 'Contrato    : ' EMP-DT-CONTRATO
               DISPLAY 'Status      : ' EMP-STATUS
               MOVE 0 TO LS-CODIGO
           END-IF.

       4000-PAGAR-PARCELA.
           DISPLAY 'ID do Emprestimo: '
           ACCEPT WS-EMP-ID-SEL
           MOVE WS-EMP-ID-SEL TO EMP-ID
           READ ARQEMPREST KEY IS EMP-ID
           IF FS-NFD-EMP
               DISPLAY 'EMPRESTIMO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF EMP-STATUS NOT = 'A'
               DISPLAY 'EMPRESTIMO NAO ATIVO (Status: ' EMP-STATUS ')'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF EMP-PARCELAS-PG >= EMP-PARCELAS-TOT
               DISPLAY 'EMPRESTIMO JA QUITADO'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE EMP-CONTA TO WS-CONTA-NUM
           PERFORM 2100-BUSCAR-CONTA
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           MOVE EMP-VALOR-PARCEL TO WS-PMT
           MOVE WS-PMT TO WS-PARCELA-EXIB
           COMPUTE WS-PARCELA-NUM-EXIB = EMP-PARCELAS-PG + 1
           DISPLAY 'Parcela ' WS-PARCELA-NUM-EXIB '/'
                   EMP-PARCELAS-TOT ': R$ ' WS-PARCELA-EXIB
           DISPLAY 'Confirmar pagamento? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO(1:1) NOT = 'S'
               DISPLAY 'CANCELADO'
               MOVE 0 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF (WS-CONTA-SALDO + WS-CONTA-LIMITE) < WS-PMT
               DISPLAY 'SALDO INSUFICIENTE'
               MOVE 1 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           PERFORM 4050-DEBITAR-RAZAO
           IF WS-BR-OK NOT = 1
               DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
               MOVE 9998 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO EMP-PARCELAS-PG
           SUBTRACT WS-PMT FROM EMP-SALDO-DEVEDOR
           IF EMP-PARCELAS-PG >= EMP-PARCELAS-TOT
               MOVE 'Q' TO EMP-STATUS
               MOVE ZEROS TO EMP-SALDO-DEVEDOR
               DISPLAY 'PARABENS! EMPRESTIMO QUITADO!'
           END-IF
           REWRITE REG-EMPREST
           IF NOT FS-OK-EMP
               DISPLAY 'ERRO AO ATUALIZAR EMP: ' FS-EMPREST
               MOVE 9 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-TRANS-ID
           MOVE WS-TRANS-ID    TO LOAN-TRANS-ID
           MOVE WS-CONTA-NUM   TO LOAN-TRANS-ORIG
           MOVE ZEROS          TO LOAN-TRANS-DEST
           MOVE 'PMT'          TO LOAN-TRANS-TIPO
           MOVE WS-PMT         TO LOAN-TRANS-VALOR
           MOVE FUNCTION CURRENT-DATE(1:8) TO LOAN-TRANS-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO LOAN-TRANS-HORA
           STRING 'Parcela emprestimo '
                  DELIMITED SIZE
                  EMP-ID DELIMITED SIZE
                  INTO LOAN-TRANS-DESCR
           MOVE 'E'            TO LOAN-TRANS-STATUS
           MOVE ZEROS          TO LOAN-TRANS-NSU
           MOVE 'MODLOAN'      TO LOAN-TRANS-CANAL
           WRITE REG-TRANS-LOAN
           DISPLAY 'PARCELA PAGA COM SUCESSO'
           MOVE 0 TO LS-CODIGO.

       4050-DEBITAR-RAZAO.
           MOVE WS-CONTA-NUM TO WS-BR-CONTA-E
           MOVE SPACES TO WS-BR-ID-STR
           STRING FUNCTION CURRENT-DATE(1:15) '-'
                  EMP-ID DELIMITED SIZE
                  INTO WS-BR-ID-STR
           COMPUTE WS-BR-VALOR-INT-N = FUNCTION INTEGER-PART(WS-PMT)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER((WS-PMT - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPL-' FUNCTION CURRENT-DATE(1:15) '.OUT'
                  DELIMITED SIZE INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle LOAN '
                  'LOAN_INSTALLMENT '
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
           STRING 'BANKTMPLS-' FUNCTION CURRENT-DATE(1:15) '.OUT'
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
                               MOVE WS-CONTA-BUF TO REG-CONTA-LOAN
                               COMPUTE LOAN-CONTA-SALDO =
                                   FUNCTION NUMVAL(WS-BR-SALDO-STR)
                               MOVE FUNCTION CURRENT-DATE(1:8) TO
                                   LOAN-CONTA-DT-ATUA
                               REWRITE REG-CONTA-LOAN
                           END-IF
                       END-IF
                   END-PERFORM
                   CLOSE ARQBRIDGE
               END-IF
           END-IF.

       5000-SIMULAR.
           DISPLAY '--- SIMULACAO DE EMPRESTIMO ---'
           DISPLAY 'Tipo (PES/CON/IMO/VEI): '
           ACCEPT WS-EMP-TIPO-SEL
           PERFORM 2200-DEFINIR-TAXA
           DISPLAY 'Valor desejado: '
           ACCEPT WS-VALOR-SOL
           DISPLAY 'Numero de parcelas: '
           ACCEPT WS-PARCELAS
           IF WS-VALOR-SOL <= ZEROS OR WS-PARCELAS <= 0
               DISPLAY 'DADOS INVALIDOS'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           PERFORM 2300-CALCULAR-PMT
           MOVE WS-VALOR-SOL   TO WS-VALOR-EXIB
           MOVE WS-PMT         TO WS-PARCELA-EXIB
           MOVE WS-TOTAL-PAGAR TO WS-TOTAL-EXIB
           DISPLAY 'Valor solicitado : R$ ' WS-VALOR-EXIB
           DISPLAY 'Parcela mensal   : R$ ' WS-PARCELA-EXIB
           DISPLAY 'Total a pagar    : R$ ' WS-TOTAL-EXIB
           COMPUTE WS-SALDO-DEV = WS-TOTAL-PAGAR - WS-VALOR-SOL
           MOVE WS-SALDO-DEV TO WS-SALDO-EXIB
           DISPLAY 'Juros totais     : R$ ' WS-SALDO-EXIB
           MOVE 0 TO LS-CODIGO.

       6000-LISTAR.
           DISPLAY 'Conta: '
           ACCEPT WS-CONTA-NUM
           MOVE WS-CONTA-NUM TO EMP-CONTA
           START ARQEMPREST KEY = EMP-CONTA
           IF FS-NFD-EMP
               DISPLAY 'NENHUM EMPRESTIMO ENCONTRADO'
               MOVE 0 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY '--- EMPRESTIMOS DA CONTA ' WS-CONTA-NUM ' ---'
           PERFORM UNTIL FS-EOF-EMP
               READ ARQEMPREST NEXT
               IF FS-OK-EMP
                   IF EMP-CONTA = WS-CONTA-NUM
                       MOVE EMP-SALDO-DEVEDOR TO WS-SALDO-EXIB
                       DISPLAY EMP-ID ' | ' EMP-TIPO
                               ' | ' EMP-PARCELAS-PG '/'
                               EMP-PARCELAS-TOT
                               ' | Saldo: R$ ' WS-SALDO-EXIB
                               ' | ' EMP-STATUS
                   ELSE
                       MOVE '10' TO FS-EMPREST
                   END-IF
               END-IF
           END-PERFORM
           MOVE 0 TO LS-CODIGO.

       7000-QUITAR.
           DISPLAY 'ID do Emprestimo: '
           ACCEPT WS-EMP-ID-SEL
           MOVE WS-EMP-ID-SEL TO EMP-ID
           READ ARQEMPREST KEY IS EMP-ID
           IF FS-NFD-EMP
               DISPLAY 'EMPRESTIMO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF EMP-STATUS NOT = 'A'
               DISPLAY 'EMPRESTIMO NAO ATIVO'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE EMP-CONTA TO WS-CONTA-NUM
           PERFORM 2100-BUSCAR-CONTA
           IF LS-CODIGO NOT = 0
               EXIT PARAGRAPH
           END-IF
           MOVE EMP-SALDO-DEVEDOR TO WS-SALDO-DEV
           MOVE WS-SALDO-DEV TO WS-SALDO-EXIB
           DISPLAY 'Saldo devedor para quitacao: R$ ' WS-SALDO-EXIB
           DISPLAY 'Confirmar quitacao antecipada? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO(1:1) NOT = 'S'
               DISPLAY 'CANCELADO'
               MOVE 0 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           IF (WS-CONTA-SALDO + WS-CONTA-LIMITE) < WS-SALDO-DEV
               DISPLAY 'SALDO INSUFICIENTE PARA QUITACAO'
               MOVE 1 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE WS-CONTA-BUF TO REG-CONTA-LOAN
           SUBTRACT WS-SALDO-DEV FROM LOAN-CONTA-SALDO
           MOVE FUNCTION CURRENT-DATE(1:8) TO LOAN-CONTA-DT-ATUA
           REWRITE REG-CONTA-LOAN
           MOVE 'Q' TO EMP-STATUS
           MOVE ZEROS TO EMP-SALDO-DEVEDOR
           MOVE EMP-PARCELAS-TOT TO EMP-PARCELAS-PG
           REWRITE REG-EMPREST
           ADD 1 TO WS-TRANS-ID
           MOVE WS-TRANS-ID    TO LOAN-TRANS-ID
           MOVE WS-CONTA-NUM   TO LOAN-TRANS-ORIG
           MOVE ZEROS          TO LOAN-TRANS-DEST
           MOVE 'PMT'          TO LOAN-TRANS-TIPO
           MOVE WS-SALDO-DEV   TO LOAN-TRANS-VALOR
           MOVE FUNCTION CURRENT-DATE(1:8) TO LOAN-TRANS-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO LOAN-TRANS-HORA
           MOVE 'Quitacao antecipada' TO LOAN-TRANS-DESCR
           MOVE 'E'            TO LOAN-TRANS-STATUS
           MOVE ZEROS          TO LOAN-TRANS-NSU
           MOVE 'MODLOAN'      TO LOAN-TRANS-CANAL
           WRITE REG-TRANS-LOAN
           DISPLAY 'EMPRESTIMO QUITADO COM SUCESSO'
           MOVE 0 TO LS-CODIGO.
