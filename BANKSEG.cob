      *================================================================
      * BANKSEG.COB - Modulo de Seguros
      * Sistema Bancario COBOL
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKSEG.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQSEG ASSIGN TO 'BANKSEG.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS SEG-APOLICE
               FILE STATUS IS FS-SEG.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQSEG.
       01  REG-SEG.
           05  SEG-APOLICE           PIC 9(12).
           05  SEG-CONTA             PIC 9(10).
           05  SEG-TIPO              PIC X(4).
           05  SEG-SEGURADO          PIC X(60).
           05  SEG-CPF               PIC X(11).
           05  SEG-VALOR-CAPITAL     PIC S9(13)V99 COMP-3.
           05  SEG-PREMIO-MENSAL     PIC S9(9)V99 COMP-3.
           05  SEG-DT-INICIO         PIC 9(8).
           05  SEG-DT-VENCTO         PIC 9(8).
           05  SEG-STATUS            PIC X(1).
           05  SEG-SINISTROS         PIC 9(3).
           05  SEG-OBS               PIC X(80).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-SEG-CTRL.
           05  FS-SEG                PIC XX.
               88  FS-SEG-OK         VALUE '00'.
               88  FS-SEG-EOF        VALUE '10'.
               88  FS-SEG-NFD        VALUE '23'.
               88  FS-SEG-DUP        VALUE '22'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  SEG-CONTINUAR     VALUE 'S'.
               88  SEG-PARAR         VALUE 'N'.
           05  WS-SEG-APL-SEQ        PIC 9(12) VALUE ZEROS.

       01  WS-SEG-PLANOS.
      *    Vida
           05  WS-VID-CAP-BASICO     PIC S9(13)V99 COMP-3 VALUE 100000,00.
           05  WS-VID-PREMIO         PIC S9(9)V99 COMP-3 VALUE 89,90.
           05  WS-VID-CAP-PLUS       PIC S9(13)V99 COMP-3 VALUE 500000,00.
           05  WS-VID-PREMIO-PLUS    PIC S9(9)V99 COMP-3 VALUE 249,90.
      *    Auto
           05  WS-AUTO-PREMIO-PC     PIC 9(3)V99 COMP-3 VALUE 3,50.
           05  WS-AUTO-FRANQUIA      PIC S9(9)V99 COMP-3 VALUE 2500,00.
      *    Residencia
           05  WS-RES-PREMIO-BASICO  PIC S9(9)V99 COMP-3 VALUE 59,90.
           05  WS-RES-CAP-BASICO     PIC S9(13)V99 COMP-3 VALUE 150000,00.
      *    Viagem
           05  WS-VGM-PREMIO-DIA     PIC S9(5)V99 COMP-3 VALUE 12,50.

       01  WS-SEG-CALC.
           05  WS-SEG-CONTA-NUM      PIC 9(10).
           05  WS-SEG-TIPO-SEL       PIC X(4).
           05  WS-SEG-VALOR-VEI      PIC S9(13)V99 COMP-3.
           05  WS-SEG-PREMIO-CALC    PIC S9(9)V99 COMP-3.
           05  WS-SEG-CAPITAL-CALC   PIC S9(13)V99 COMP-3.
           05  WS-SEG-DIAS           PIC 9(4).
           05  WS-SEG-DIS-PREM       PIC ZZ.ZZZ.ZZZ,99-.
           05  WS-SEG-DIS-CAP        PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-SEG-APL-NUM        PIC 9(12).

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQSEG
           IF NOT FS-SEG-OK
               OPEN OUTPUT ARQSEG
               CLOSE ARQSEG
               OPEN I-O ARQSEG
           END-IF
           PERFORM 9900-CARREGAR-SEQ
           PERFORM 1000-MENU UNTIL SEG-PARAR
           CLOSE ARQSEG
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-CARREGAR-SEQ.
           MOVE 999999999999 TO SEG-APOLICE
           START ARQSEG KEY <= SEG-APOLICE
           READ ARQSEG PREVIOUS
           IF FS-SEG-OK
               MOVE SEG-APOLICE TO WS-SEG-APL-SEQ
           ELSE
               MOVE ZEROS TO WS-SEG-APL-SEQ
           END-IF.

      *================================================================
       1000-MENU SECTION.
      *================================================================
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '           SEGUROS'
           DISPLAY '========================================'
           DISPLAY ' 01. Contratar Seguro de Vida'
           DISPLAY ' 02. Contratar Seguro Auto'
           DISPLAY ' 03. Contratar Seguro Residencia'
           DISPLAY ' 04. Contratar Seguro Viagem'
           DISPLAY ' 05. Consultar Apolices'
           DISPLAY ' 06. Acionar Sinistro'
           DISPLAY ' 07. Cancelar Apolice'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-SEGURO-VIDA
               WHEN '02' PERFORM 3000-SEGURO-AUTO
               WHEN '03' PERFORM 4000-SEGURO-RESIDENCIA
               WHEN '04' PERFORM 5000-SEGURO-VIAGEM
               WHEN '05' PERFORM 6000-CONSULTAR-APOLICES
               WHEN '06' PERFORM 7000-ACIONAR-SINISTRO
               WHEN '07' PERFORM 8000-CANCELAR-APOLICE
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

      *================================================================
       2000-SEGURO-VIDA SECTION.
      *================================================================
       2000-INICIO.
           DISPLAY '--- SEGURO DE VIDA ---'
           DISPLAY 'Conta debito mensal: '
           ACCEPT WS-SEG-CONTA-NUM
           DISPLAY 'Nome do segurado: '
           ACCEPT WS-CONTA-TITULAR
           DISPLAY 'CPF do segurado: '
           ACCEPT WS-CONTA-CPF
           DISPLAY 'Plano (1=Basico R$89,90 2=Plus R$249,90): '
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '1'
                   MOVE WS-VID-CAP-BASICO TO WS-SEG-CAPITAL-CALC
                   MOVE WS-VID-PREMIO TO WS-SEG-PREMIO-CALC
               WHEN '2'
                   MOVE WS-VID-CAP-PLUS TO WS-SEG-CAPITAL-CALC
                   MOVE WS-VID-PREMIO-PLUS TO WS-SEG-PREMIO-CALC
               WHEN OTHER
                   DISPLAY 'PLANO INVALIDO'
                   MOVE 1 TO LS-CODIGO
                   EXIT SECTION
           END-EVALUATE
           MOVE WS-SEG-CAPITAL-CALC TO WS-SEG-DIS-CAP
           MOVE WS-SEG-PREMIO-CALC TO WS-SEG-DIS-PREM
           DISPLAY 'Capital segurado: R$ ' WS-SEG-DIS-CAP
           DISPLAY 'Premio mensal:    R$ ' WS-SEG-DIS-PREM
           DISPLAY 'Coberturas: Morte natural/acidental,'
           DISPLAY '            Invalidez permanente,'
           DISPLAY '            Doencas graves (12)'
           DISPLAY 'Confirmar contratacao? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'VIDA' TO WS-SEG-TIPO-SEL
               PERFORM 9800-GRAVAR-APOLICE
               DISPLAY 'APOLICE CONTRATADA! No.: ' WS-SEG-APL-NUM
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CONTRATACAO CANCELADA'
           END-IF.

      *================================================================
       3000-SEGURO-AUTO SECTION.
      *================================================================
       3000-INICIO.
           DISPLAY '--- SEGURO AUTOMOTIVO ---'
           DISPLAY 'Conta debito mensal: '
           ACCEPT WS-SEG-CONTA-NUM
           DISPLAY 'Nome do segurado/proprietario: '
           ACCEPT WS-CONTA-TITULAR
           DISPLAY 'CPF: '
           ACCEPT WS-CONTA-CPF
           DISPLAY 'Valor do veiculo (R$): '
           ACCEPT WS-SEG-VALOR-VEI
           COMPUTE WS-SEG-PREMIO-CALC ROUNDED =
               WS-SEG-VALOR-VEI * WS-AUTO-PREMIO-PC / 100
           COMPUTE WS-SEG-PREMIO-CALC =
               WS-SEG-PREMIO-CALC / 12
           MOVE WS-SEG-VALOR-VEI TO WS-SEG-CAPITAL-CALC
           MOVE WS-SEG-PREMIO-CALC TO WS-SEG-DIS-PREM
           MOVE WS-AUTO-FRANQUIA TO WS-SEG-DIS-CAP
           DISPLAY 'Premio mensal estimado: R$ ' WS-SEG-DIS-PREM
           DISPLAY 'Franquia:               R$ ' WS-SEG-DIS-CAP
           DISPLAY 'Coberturas: Colisao, Roubo/Furto,'
           DISPLAY '            Danos a terceiros, Incendio'
           DISPLAY 'Assistencia 24h incluida'
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'AUTO' TO WS-SEG-TIPO-SEL
               PERFORM 9800-GRAVAR-APOLICE
               DISPLAY 'APOLICE CONTRATADA! No.: ' WS-SEG-APL-NUM
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CONTRATACAO CANCELADA'
           END-IF.

      *================================================================
       4000-SEGURO-RESIDENCIA SECTION.
      *================================================================
       4000-INICIO.
           DISPLAY '--- SEGURO RESIDENCIAL ---'
           DISPLAY 'Conta debito mensal: '
           ACCEPT WS-SEG-CONTA-NUM
           DISPLAY 'Nome do titular: '
           ACCEPT WS-CONTA-TITULAR
           DISPLAY 'CPF: '
           ACCEPT WS-CONTA-CPF
           MOVE WS-RES-CAP-BASICO TO WS-SEG-CAPITAL-CALC
           MOVE WS-RES-PREMIO-BASICO TO WS-SEG-PREMIO-CALC
           MOVE WS-SEG-DIS-CAP TO WS-SEG-DIS-CAP
           MOVE WS-RES-PREMIO-BASICO TO WS-SEG-DIS-PREM
           MOVE WS-RES-CAP-BASICO TO WS-SEG-DIS-CAP
           DISPLAY 'Capital segurado: R$ ' WS-SEG-DIS-CAP
           DISPLAY 'Premio mensal:    R$ ' WS-SEG-DIS-PREM
           DISPLAY 'Coberturas: Incendio, Roubo,'
           DISPLAY '            Danos eletricos, Vendaval'
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'RESI' TO WS-SEG-TIPO-SEL
               PERFORM 9800-GRAVAR-APOLICE
               DISPLAY 'APOLICE CONTRATADA! No.: ' WS-SEG-APL-NUM
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CONTRATACAO CANCELADA'
           END-IF.

      *================================================================
       5000-SEGURO-VIAGEM SECTION.
      *================================================================
       5000-INICIO.
           DISPLAY '--- SEGURO VIAGEM ---'
           DISPLAY 'Conta debito: '
           ACCEPT WS-SEG-CONTA-NUM
           DISPLAY 'Nome do viajante: '
           ACCEPT WS-CONTA-TITULAR
           DISPLAY 'CPF: '
           ACCEPT WS-CONTA-CPF
           DISPLAY 'Numero de dias da viagem: '
           ACCEPT WS-SEG-DIAS
           COMPUTE WS-SEG-PREMIO-CALC =
               WS-SEG-DIAS * WS-VGM-PREMIO-DIA
           MOVE 5000000,00 TO WS-SEG-CAPITAL-CALC
           MOVE WS-SEG-PREMIO-CALC TO WS-SEG-DIS-PREM
           DISPLAY 'Dias: ' WS-SEG-DIAS
           DISPLAY 'Premio total:    R$ ' WS-SEG-DIS-PREM
           DISPLAY 'Coberturas: Medica/hospitalar USD5M,'
           DISPLAY '            Cancelamento de voo,'
           DISPLAY '            Extravio de bagagem,'
           DISPLAY '            Assistencia juridica'
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'VIAG' TO WS-SEG-TIPO-SEL
               PERFORM 9800-GRAVAR-APOLICE
               DISPLAY 'APOLICE CONTRATADA! No.: ' WS-SEG-APL-NUM
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CONTRATACAO CANCELADA'
           END-IF.

      *================================================================
       6000-CONSULTAR-APOLICES SECTION.
      *================================================================
       6000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-SEG-CONTA-NUM
           DISPLAY '========================================'
           DISPLAY ' SUAS APOLICES'
           DISPLAY ' Apolice      Tipo  Premio/mes  Status'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO SEG-APOLICE
           START ARQSEG KEY >= SEG-APOLICE
           PERFORM UNTIL FS-SEG-EOF
               READ ARQSEG NEXT
               IF FS-SEG-OK
                   IF SEG-CONTA = WS-SEG-CONTA-NUM
                       MOVE SEG-PREMIO-MENSAL TO WS-SEG-DIS-PREM
                       DISPLAY SEG-APOLICE ' '
                               SEG-TIPO '  R$ '
                               WS-SEG-DIS-PREM '  '
                               SEG-STATUS
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       7000-ACIONAR-SINISTRO SECTION.
      *================================================================
       7000-INICIO.
           DISPLAY '--- ACIONAR SINISTRO ---'
           DISPLAY 'Numero da Apolice: '
           ACCEPT WS-SEG-APL-NUM
           MOVE WS-SEG-APL-NUM TO SEG-APOLICE
           READ ARQSEG KEY IS SEG-APOLICE
           IF FS-SEG-NFD
               DISPLAY 'APOLICE NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF SEG-STATUS NOT = 'A'
               DISPLAY 'APOLICE NAO ESTA ATIVA'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE SEG-CAPITAL-SEGURADO TO WS-SEG-DIS-CAP
           DISPLAY 'Apolice: ' SEG-TIPO ' - Capital: R$ ' WS-SEG-DIS-CAP
           DISPLAY 'Descricao do sinistro: '
           ACCEPT SEG-OBS
           ADD 1 TO SEG-SINISTROS
           REWRITE REG-SEG
           DISPLAY 'SINISTRO REGISTRADO!'
           DISPLAY 'Protocolo: ' SEG-APOLICE '-' SEG-SINISTROS
           DISPLAY 'Prazo resposta: 5 dias uteis'
           DISPLAY 'Regulador sera contatado em 24h'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       8000-CANCELAR-APOLICE SECTION.
      *================================================================
       8000-INICIO.
           DISPLAY 'Numero da Apolice: '
           ACCEPT WS-SEG-APL-NUM
           MOVE WS-SEG-APL-NUM TO SEG-APOLICE
           READ ARQSEG KEY IS SEG-APOLICE
           IF FS-SEG-NFD
               DISPLAY 'APOLICE NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Apolice: ' SEG-TIPO ' / Status: ' SEG-STATUS
           DISPLAY 'Confirmar cancelamento? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'C' TO SEG-STATUS
               REWRITE REG-SEG
               DISPLAY 'APOLICE CANCELADA COM SUCESSO'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO CANCELADA'
           END-IF.

      *================================================================
       9800-GRAVAR-APOLICE.
      *================================================================
           ADD 1 TO WS-SEG-APL-SEQ
           MOVE WS-SEG-APL-SEQ TO SEG-APOLICE
           MOVE WS-SEG-APL-SEQ TO WS-SEG-APL-NUM
           MOVE WS-SEG-CONTA-NUM TO SEG-CONTA
           MOVE WS-SEG-TIPO-SEL TO SEG-TIPO
           MOVE WS-CONTA-TITULAR TO SEG-SEGURADO
           MOVE WS-CONTA-CPF TO SEG-CPF
           MOVE WS-SEG-CAPITAL-CALC TO SEG-VALOR-CAPITAL
           MOVE WS-SEG-PREMIO-CALC TO SEG-PREMIO-MENSAL
           MOVE FUNCTION CURRENT-DATE(1:8) TO SEG-DT-INICIO
           MOVE ZEROS TO SEG-DT-VENCTO
           MOVE 'A' TO SEG-STATUS
           MOVE ZEROS TO SEG-SINISTROS
           MOVE SPACES TO SEG-OBS
           WRITE REG-SEG
           IF NOT FS-SEG-OK
               DISPLAY 'ERRO AO GRAVAR APOLICE: ' FS-SEG
               MOVE 9999 TO LS-CODIGO
           END-IF.

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
