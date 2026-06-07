      *================================================================
      * BANKPJ.COB - Conta Digital PJ / MEI (Pessoa Juridica)
      * Sistema Bancario COBOL
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKPJ.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQPJ ASSIGN TO 'BANKPJ.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS PJ-CONTA
               ALTERNATE RECORD KEY IS PJ-CNPJ WITH DUPLICATES
               FILE STATUS IS FS-PJ.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQPJ.
       01  REG-PJ.
           05  PJ-CONTA              PIC 9(10).
           05  PJ-CNPJ               PIC X(14).
           05  PJ-RAZAO-SOCIAL       PIC X(60).
           05  PJ-NOME-FANTASIA      PIC X(40).
           05  PJ-REGIME             PIC X(12).
           05  PJ-FATURAMENTO-MES    PIC S9(11)V99 COMP-3.
           05  PJ-FATURAMENTO-ANO    PIC S9(11)V99 COMP-3.
           05  PJ-LIMITE-MEI         PIC S9(11)V99 COMP-3.
           05  PJ-DT-ABERTURA        PIC 9(8).
           05  PJ-STATUS             PIC X(1).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-PJ-CTRL.
           05  FS-PJ                 PIC XX.
               88  FS-PJ-OK          VALUE '00'.
               88  FS-PJ-EOF         VALUE '10'.
               88  FS-PJ-NFD         VALUE '23'.
               88  FS-PJ-DUP         VALUE '22'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  PJ-PARAR          VALUE 'N'.

       01  WS-PJ-CALC.
           05  WS-PJ-CONTA-NUM       PIC 9(10).
           05  WS-PJ-DAS             PIC S9(7)V99 COMP-3.
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQPJ
           IF NOT FS-PJ-OK
               OPEN OUTPUT ARQPJ
               CLOSE ARQPJ
               OPEN I-O ARQPJ
           END-IF
           PERFORM 1000-MENU UNTIL PJ-PARAR
           CLOSE ARQPJ
           MOVE 0 TO LS-CODIGO
           GOBACK.

      *================================================================
       1000-MENU SECTION.
      *================================================================
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '       CONTA DIGITAL PJ / MEI'
           DISPLAY '========================================'
           DISPLAY ' 01. Abrir Conta PJ/MEI'
           DISPLAY ' 02. Consultar Dados da Empresa'
           DISPLAY ' 03. Emitir Guia DAS (MEI)'
           DISPLAY ' 04. Registrar Faturamento Mensal'
           DISPLAY ' 05. Relatorio Simplificado p/ Contador'
           DISPLAY ' 06. Consultar Enquadramento Tributario'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-ABRIR
               WHEN '02' PERFORM 3000-CONSULTAR
               WHEN '03' PERFORM 4000-EMITIR-DAS
               WHEN '04' PERFORM 5000-FATURAMENTO
               WHEN '05' PERFORM 6000-RELATORIO
               WHEN '06' PERFORM 7000-ENQUADRAMENTO
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

      *================================================================
       2000-ABRIR SECTION.
      *================================================================
       2000-INICIO.
           DISPLAY '--- ABRIR CONTA PJ/MEI ---'
           DISPLAY 'Numero da conta: '
           ACCEPT PJ-CONTA
           DISPLAY 'CNPJ: '
           ACCEPT PJ-CNPJ
           DISPLAY 'Razao social: '
           ACCEPT PJ-RAZAO-SOCIAL
           DISPLAY 'Nome fantasia: '
           ACCEPT PJ-NOME-FANTASIA
           DISPLAY 'Regime tributario (MEI/SIMPLES/PRESUMIDO): '
           ACCEPT PJ-REGIME
           MOVE ZEROS TO PJ-FATURAMENTO-MES PJ-FATURAMENTO-ANO
           IF PJ-REGIME = 'MEI'
               MOVE 81000,00 TO PJ-LIMITE-MEI
           ELSE
               MOVE 4800000,00 TO PJ-LIMITE-MEI
           END-IF
           MOVE FUNCTION CURRENT-DATE(1:8) TO PJ-DT-ABERTURA
           MOVE 'A' TO PJ-STATUS
           WRITE REG-PJ
           IF FS-PJ-OK
               DISPLAY 'CONTA PJ/MEI ABERTA COM SUCESSO!'
               DISPLAY ' Conta: ' PJ-CONTA
               MOVE PJ-LIMITE-MEI TO WS-DIS
               DISPLAY ' Limite anual de faturamento: R$ ' WS-DIS
               DISPLAY ' Isenta de tarifa de manutencao mensal'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO: ' FS-PJ
               MOVE 9999 TO LS-CODIGO
           END-IF.

      *================================================================
       3000-CONSULTAR SECTION.
      *================================================================
       3000-INICIO.
           DISPLAY 'Conta PJ: '
           ACCEPT WS-PJ-CONTA-NUM
           MOVE WS-PJ-CONTA-NUM TO PJ-CONTA
           READ ARQPJ KEY IS PJ-CONTA
           IF FS-PJ-NFD
               DISPLAY 'CONTA PJ NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY '========================================'
           DISPLAY ' Razao social: ' PJ-RAZAO-SOCIAL(1:40)
           DISPLAY ' Nome fantasia: ' PJ-NOME-FANTASIA(1:30)
           DISPLAY ' CNPJ: ' PJ-CNPJ
           DISPLAY ' Regime: ' PJ-REGIME
           MOVE PJ-FATURAMENTO-ANO TO WS-DIS
           DISPLAY ' Faturamento no ano: R$ ' WS-DIS
           MOVE PJ-LIMITE-MEI TO WS-DIS
           DISPLAY ' Limite do regime: R$ ' WS-DIS
           DISPLAY ' Aberta em: ' PJ-DT-ABERTURA
           DISPLAY ' Status: ' PJ-STATUS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       4000-EMITIR-DAS SECTION.
      *================================================================
       4000-INICIO.
           DISPLAY 'Conta PJ: '
           ACCEPT WS-PJ-CONTA-NUM
           MOVE WS-PJ-CONTA-NUM TO PJ-CONTA
           READ ARQPJ KEY IS PJ-CONTA
           IF FS-PJ-NFD
               DISPLAY 'CONTA PJ NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF PJ-REGIME NOT = 'MEI'
               DISPLAY 'GUIA DAS DISPONIVEL APENAS PARA MEI'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
      *    DAS-MEI: valor fixo aproximado (INSS + ICMS/ISS)
           MOVE 75,90 TO WS-PJ-DAS
           DISPLAY '========================================'
           DISPLAY ' GUIA DAS - MEI'
           DISPLAY ' CNPJ: ' PJ-CNPJ
           DISPLAY ' Competencia: ' FUNCTION CURRENT-DATE(1:6)
           MOVE WS-PJ-DAS TO WS-DIS
           DISPLAY ' Valor a recolher: R$ ' WS-DIS
           DISPLAY ' Vencimento: dia 20 do mes seguinte'
           DISPLAY ' (INSS R$ 70,60 + ICMS/ISS R$ 5,30)'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       5000-FATURAMENTO SECTION.
      *================================================================
       5000-INICIO.
           DISPLAY 'Conta PJ: '
           ACCEPT WS-PJ-CONTA-NUM
           MOVE WS-PJ-CONTA-NUM TO PJ-CONTA
           READ ARQPJ KEY IS PJ-CONTA
           IF FS-PJ-NFD
               DISPLAY 'CONTA PJ NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Faturamento do mes (R$): '
           ACCEPT PJ-FATURAMENTO-MES
           ADD PJ-FATURAMENTO-MES TO PJ-FATURAMENTO-ANO
           REWRITE REG-PJ
           MOVE PJ-FATURAMENTO-ANO TO WS-DIS
           DISPLAY 'FATURAMENTO REGISTRADO!'
           DISPLAY ' Acumulado no ano: R$ ' WS-DIS
           IF PJ-FATURAMENTO-ANO > PJ-LIMITE-MEI
               DISPLAY '*** ATENCAO: LIMITE DO REGIME EXCEDIDO! ***'
               DISPLAY ' Procure orientacao para reenquadramento'
           ELSE
               COMPUTE WS-PJ-DAS ROUNDED =
                   (PJ-LIMITE-MEI - PJ-FATURAMENTO-ANO)
               MOVE WS-PJ-DAS TO WS-DIS
               DISPLAY ' Margem restante no limite: R$ ' WS-DIS
           END-IF
           MOVE 0 TO LS-CODIGO.

      *================================================================
       6000-RELATORIO SECTION.
      *================================================================
       6000-INICIO.
           DISPLAY 'Conta PJ: '
           ACCEPT WS-PJ-CONTA-NUM
           MOVE WS-PJ-CONTA-NUM TO PJ-CONTA
           READ ARQPJ KEY IS PJ-CONTA
           IF FS-PJ-NFD
               DISPLAY 'CONTA PJ NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY '========================================'
           DISPLAY ' RELATORIO SIMPLIFICADO P/ CONTADOR'
           DISPLAY '----------------------------------------'
           DISPLAY ' Empresa: ' PJ-RAZAO-SOCIAL(1:40)
           DISPLAY ' CNPJ: ' PJ-CNPJ
           DISPLAY ' Regime: ' PJ-REGIME
           MOVE PJ-FATURAMENTO-MES TO WS-DIS
           DISPLAY ' Faturamento ultimo mes: R$ ' WS-DIS
           MOVE PJ-FATURAMENTO-ANO TO WS-DIS
           DISPLAY ' Faturamento acumulado no ano: R$ ' WS-DIS
           MOVE PJ-LIMITE-MEI TO WS-DIS
           DISPLAY ' Limite do regime: R$ ' WS-DIS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       7000-ENQUADRAMENTO SECTION.
      *================================================================
       7000-INICIO.
           DISPLAY '========================================'
           DISPLAY ' FAIXAS DE ENQUADRAMENTO TRIBUTARIO'
           DISPLAY '----------------------------------------'
           DISPLAY ' MEI:        ate R$  81.000,00 / ano'
           DISPLAY ' SIMPLES:    ate R$ 4.800.000,00 / ano'
           DISPLAY ' PRESUMIDO:  acima de R$ 4.800.000,00'
           DISPLAY '----------------------------------------'
           DISPLAY ' Ao se aproximar do limite, considere'
           DISPLAY ' planejar o reenquadramento tributario.'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
