      *================================================================
      * BANKINV.COB - Módulo de Investimentos
      * Sistema Bancário COBOL
      * Padrão: Strategy Pattern para Produtos Financeiros
      * Versão: 2.0
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKINV.

      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQINV ASSIGN TO 'BANKINV.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS REG-INV-ID
               FILE STATUS IS FS-INV.

      *----------------------------------------------------------------
       DATA DIVISION.
       FILE SECTION.
       FD  ARQINV.
       01  REG-INV.
           05  REG-INV-ID            PIC 9(10).
           05  REG-INV-CONTA         PIC 9(10).
           05  REG-INV-TIPO          PIC X(3).
           05  REG-INV-VALOR-APORT   PIC S9(13)V99 COMP-3.
           05  REG-INV-VALOR-ATUAL   PIC S9(13)V99 COMP-3.
           05  REG-INV-TAXA          PIC S9(5)V9(6) COMP-3.
           05  REG-INV-DT-INICIO     PIC 9(8).
           05  REG-INV-PRAZO         PIC 9(4).
           05  REG-INV-STATUS        PIC X(1).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-INV-CTRL.
           05  FS-INV               PIC XX.
               88  FS-INV-OK        VALUE '00'.
               88  FS-INV-EOF       VALUE '10'.
               88  FS-INV-NFD       VALUE '23'.
               88  FS-INV-DUP       VALUE '22'.
           05  WS-INV-ID-SEQ        PIC 9(10) VALUE ZEROS.
           05  WS-OPCAO-INV         PIC X(2).
           05  WS-CONTINUAR         PIC X VALUE 'S'.
               88  INV-CONTINUAR    VALUE 'S'.
               88  INV-PARAR        VALUE 'N'.
           05  WS-INV-DIS           PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-INV-CTR           PIC 9(6) COMP-3.
           05  WS-INV-TOTAL         PIC S9(13)V99 COMP-3.

       01  WS-CALC-INVEST.
           05  WS-PRAZO-DIAS        PIC 9(4) COMP-3.
           05  WS-TAXA-ANUAL        PIC 9(5)V9(6) COMP-3.
           05  WS-TAXA-DIARIA       PIC 9(3)V9(10) COMP-3.
           05  WS-FATOR-ACRESC      PIC 9(3)V9(10) COMP-3.
           05  WS-VALOR-BRUTO       PIC S9(13)V99 COMP-3.
           05  WS-IMPOSTO           PIC S9(11)V99 COMP-3.
           05  WS-VALOR-LIQUIDO     PIC S9(13)V99 COMP-3.
           05  WS-PERC-IMPOSTO      PIC 9(2)V99 COMP-3.
           05  WS-VL-DISPLAY        PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.

       01  WS-TAXAS-MERCADO.
           05  WS-CDI-ATUAL        PIC 9(3)V9(6) COMP-3 VALUE 10,500000.
           05  WS-SELIC-ATUAL      PIC 9(3)V9(6) COMP-3 VALUE 10,500000.
           05  WS-IPCA-ATUAL        PIC 9(3)V9(6) COMP-3 VALUE 4,620000.
           05  WS-IGPM-ATUAL        PIC 9(3)V9(6) COMP-3 VALUE 3,890000.

       01  WS-PRODUTOS.
           05  WS-PROD-CDB-PERC-CDI PIC 9(3)V99 COMP-3 VALUE 105,00.
           05  WS-PROD-LCI-PERC-CDI PIC 9(3)V99 COMP-3 VALUE 95,00.
           05  WS-PROD-LCA-PERC-CDI PIC 9(3)V99 COMP-3 VALUE 93,00.
           05  WS-PROD-TESOURO-TAXA PIC 9(2)V99 COMP-3 VALUE 11,87.
           05  WS-APLIC-MIN-CDB     PIC S9(9)V99 COMP-3 VALUE 1000,00.
           05  WS-APLIC-MIN-LCI     PIC S9(9)V99 COMP-3 VALUE 5000,00.
           05  WS-APLIC-MIN-TESOURO PIC S9(9)V99 COMP-3 VALUE 30,00.

      *----------------------------------------------------------------
       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO            PIC 9(4).
           05  LS-MENSAGEM          PIC X(100).

      *----------------------------------------------------------------
       PROCEDURE DIVISION USING LS-RETORNO.

      *================================================================
       0000-PRINCIPAL SECTION.
      *================================================================
       0000-INICIO.
           OPEN I-O ARQINV
           IF NOT FS-INV-OK
               OPEN OUTPUT ARQINV
               CLOSE ARQINV
               OPEN I-O ARQINV
           END-IF
           PERFORM 1000-MENU-INV UNTIL INV-PARAR
           CLOSE ARQINV
           MOVE 0 TO LS-CODIGO
           GOBACK.

      *================================================================
       1000-MENU-INV SECTION.
      *================================================================
       1000-INICIO.
           DISPLAY '======================================='
           DISPLAY '         INVESTIMENTOS'
           DISPLAY '======================================='
           DISPLAY 'CDI: ' WS-CDI-ATUAL '% a.a.'
           DISPLAY 'SELIC: ' WS-SELIC-ATUAL '% a.a.'
           DISPLAY 'IPCA: ' WS-IPCA-ATUAL '% a.a.'
           DISPLAY '---------------------------------------'
           DISPLAY ' 01. Aplicar em CDB'
           DISPLAY ' 02. Aplicar em LCI (Isento IR)'
           DISPLAY ' 03. Aplicar em LCA (Isento IR)'
           DISPLAY ' 04. Aplicar em Tesouro Direto'
           DISPLAY ' 05. Aplicar em Fundo de Investimento'
           DISPLAY ' 06. Resgatar Investimento'
           DISPLAY ' 07. Consultar Carteira'
           DISPLAY ' 08. Simular Investimento'
           DISPLAY ' 09. Relatorio de Rentabilidade'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO-INV

           EVALUATE WS-OPCAO-INV
               WHEN '01'  PERFORM 2000-APLICAR-CDB
               WHEN '02'  PERFORM 2500-APLICAR-LCI
               WHEN '03'  PERFORM 2700-APLICAR-LCA
               WHEN '04'  PERFORM 3000-APLICAR-TESOURO
               WHEN '05'  PERFORM 3500-APLICAR-FUNDO
               WHEN '06'  PERFORM 4000-RESGATAR
               WHEN '07'  PERFORM 5000-CONSULTAR-CARTEIRA
               WHEN '08'  PERFORM 6000-SIMULAR
               WHEN '09'  PERFORM 7000-RELATORIO-RENTAB
               WHEN '00'  MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

      *================================================================
       2000-APLICAR-CDB SECTION.
      *================================================================
       2000-INICIO.
           DISPLAY '--- CDB ---'
           DISPLAY 'Taxa: ' WS-PROD-CDB-PERC-CDI '% do CDI'
           DISPLAY 'Aplicacao Minima: R$ 1.000,00'
           DISPLAY 'Valor da Aplicacao: R$ '
           ACCEPT WS-INV-VALOR-APORT
           IF WS-INV-VALOR-APORT < WS-APLIC-MIN-CDB
               DISPLAY 'VALOR ABAIXO DO MINIMO'
               MOVE 0003 TO LS-CODIGO
           ELSE
               DISPLAY 'Prazo (dias): '
               ACCEPT WS-PRAZO-DIAS
               PERFORM 2100-CALC-RENTABILIDADE-CDB
               PERFORM 2200-CONFIRMAR-APLICACAO
           END-IF.

       2100-CALC-RENTABILIDADE-CDB.
      *    Taxa diaria = (1 + taxa_anual)^(1/252) - 1
      *    Usando EXP(LOG(1+r)/252) pois COBOL nao tem expoente fracionario
           COMPUTE WS-TAXA-ANUAL =
               (WS-CDI-ATUAL * WS-PROD-CDB-PERC-CDI / 100) / 100
           COMPUTE WS-TAXA-DIARIA =
               FUNCTION EXP(FUNCTION LOG(1 + WS-TAXA-ANUAL) / 252) - 1
      *    Valor bruto
           COMPUTE WS-FATOR-ACRESC =
               (1 + WS-TAXA-DIARIA) ** WS-PRAZO-DIAS
           COMPUTE WS-VALOR-BRUTO =
               WS-INV-VALOR-APORT * WS-FATOR-ACRESC
      *    IR regressivo CDB
           EVALUATE TRUE
               WHEN WS-PRAZO-DIAS <= 180
                   MOVE 22,50 TO WS-PERC-IMPOSTO
               WHEN WS-PRAZO-DIAS <= 360
                   MOVE 20,00 TO WS-PERC-IMPOSTO
               WHEN WS-PRAZO-DIAS <= 720
                   MOVE 17,50 TO WS-PERC-IMPOSTO
               WHEN OTHER
                   MOVE 15,00 TO WS-PERC-IMPOSTO
           END-EVALUATE
           COMPUTE WS-IMPOSTO =
               (WS-VALOR-BRUTO - WS-INV-VALOR-APORT) *
               WS-PERC-IMPOSTO / 100
           COMPUTE WS-VALOR-LIQUIDO =
               WS-VALOR-BRUTO - WS-IMPOSTO.

       2200-CONFIRMAR-APLICACAO.
           MOVE WS-INV-VALOR-APORT TO WS-VL-DISPLAY
           DISPLAY 'Aplicacao: R$ ' WS-VL-DISPLAY
           MOVE WS-VALOR-BRUTO TO WS-VL-DISPLAY
           DISPLAY 'Valor Bruto Futuro: R$ ' WS-VL-DISPLAY
           MOVE WS-IMPOSTO TO WS-VL-DISPLAY
           DISPLAY 'IR (' WS-PERC-IMPOSTO '%): R$ ' WS-VL-DISPLAY
           MOVE WS-VALOR-LIQUIDO TO WS-VL-DISPLAY
           DISPLAY 'Valor Liquido: R$ ' WS-VL-DISPLAY
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-INV-TIPO
           IF WS-INV-TIPO = 'S'
               ADD 1 TO WS-INV-ID-SEQ
               MOVE WS-INV-ID-SEQ TO REG-INV-ID
               MOVE WS-INV-CONTA TO REG-INV-CONTA
               MOVE WS-INV-TIPO TO REG-INV-TIPO
               MOVE WS-INV-VALOR-APORT TO REG-INV-VALOR-APORT
               MOVE WS-VALOR-LIQUIDO TO REG-INV-VALOR-ATUAL
               MOVE WS-TAXA-ANUAL TO REG-INV-TAXA
               MOVE FUNCTION CURRENT-DATE(1:8) TO REG-INV-DT-INICIO
               MOVE WS-PRAZO-DIAS TO REG-INV-PRAZO
               MOVE 'A' TO REG-INV-STATUS
               WRITE REG-INV
               IF FS-INV-OK
                   DISPLAY 'APLICACAO REALIZADA! ID: ' REG-INV-ID
                   MOVE 0 TO LS-CODIGO
               ELSE
                   DISPLAY 'ERRO AO GRAVAR: ' FS-INV
                   MOVE 9999 TO LS-CODIGO
               END-IF
           ELSE
               DISPLAY 'OPERACAO CANCELADA'
           END-IF.

       2500-APLICAR-LCI.
           DISPLAY '--- LCI (Isento de IR) ---'
           DISPLAY 'Taxa: ' WS-PROD-LCI-PERC-CDI '% do CDI'
           DISPLAY 'Aplicacao Minima: R$ 5.000,00'
           DISPLAY 'Valor: '
           ACCEPT WS-INV-VALOR-APORT
           IF WS-INV-VALOR-APORT >= WS-APLIC-MIN-LCI
               DISPLAY 'APLICACAO LCI REALIZADA - SEM IR!'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'VALOR ABAIXO DO MINIMO (R$ 5.000,00)'
               MOVE 0003 TO LS-CODIGO
           END-IF.

       2700-APLICAR-LCA.
           DISPLAY '--- LCA (Isento de IR) ---'
           DISPLAY 'Taxa: ' WS-PROD-LCA-PERC-CDI '% do CDI'
           DISPLAY 'APLICACAO LCA PROCESSADA'
           MOVE 0 TO LS-CODIGO.

       3000-APLICAR-TESOURO.
           DISPLAY '--- TESOURO DIRETO ---'
           DISPLAY ' 1. Tesouro Selic (pós-fixado)'
           DISPLAY ' 2. Tesouro IPCA+ (inflacao + juros)'
           DISPLAY ' 3. Tesouro Prefixado'
           DISPLAY 'Taxa min. aplicacao: R$ 30,00'
           MOVE 0 TO LS-CODIGO.

       3500-APLICAR-FUNDO.
           DISPLAY '--- FUNDOS DE INVESTIMENTO ---'
           DISPLAY ' RF: Renda Fixa DI (baixo risco)'
           DISPLAY ' MM: Multimercado (medio risco)'
           DISPLAY ' AE: Acoes (alto risco/retorno)'
           MOVE 0 TO LS-CODIGO.

       4000-RESGATAR.
           DISPLAY 'ID do Investimento: '
           ACCEPT WS-INV-ID
           MOVE WS-INV-ID TO REG-INV-ID
           READ ARQINV KEY IS REG-INV-ID
           IF FS-INV-NFD
               DISPLAY 'INVESTIMENTO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
           ELSE IF FS-INV-OK
               IF REG-INV-STATUS = 'R'
                   DISPLAY 'INVESTIMENTO JA RESGATADO'
                   MOVE 4 TO LS-CODIGO
               ELSE
                   MOVE REG-INV-VALOR-ATUAL TO WS-INV-DIS
                   DISPLAY 'Valor: R$ ' WS-INV-DIS
                   MOVE 'R' TO REG-INV-STATUS
                   REWRITE REG-INV
                   IF FS-INV-OK
                       DISPLAY 'RESGATE PROCESSADO COM SUCESSO!'
                       MOVE 0 TO LS-CODIGO
                   ELSE
                       DISPLAY 'ERRO NO RESGATE: ' FS-INV
                       MOVE 9999 TO LS-CODIGO
                   END-IF
               END-IF
           ELSE
               DISPLAY 'ERRO DE LEITURA: ' FS-INV
               MOVE 9999 TO LS-CODIGO
           END-IF.

       5000-CONSULTAR-CARTEIRA.
           MOVE ZEROS TO WS-INV-CTR WS-INV-TOTAL
           DISPLAY '==================================='
           DISPLAY ' CARTEIRA DE INVESTIMENTOS'
           DISPLAY '==================================='
           DISPLAY ' ID         Tipo  Valor Aportado  Status'
           DISPLAY '-----------------------------------'
           MOVE ZEROS TO REG-INV-ID
           START ARQINV KEY >= REG-INV-ID
           PERFORM UNTIL FS-INV-EOF
               READ ARQINV NEXT
               IF FS-INV-OK
                   MOVE REG-INV-VALOR-ATUAL TO WS-INV-DIS
                   DISPLAY REG-INV-ID ' '
                           REG-INV-TIPO '  R$ '
                           WS-INV-DIS ' '
                           REG-INV-STATUS
                   IF REG-INV-STATUS = 'A'
                       ADD REG-INV-VALOR-ATUAL TO WS-INV-TOTAL
                       ADD 1 TO WS-INV-CTR
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '-----------------------------------'
           MOVE WS-INV-TOTAL TO WS-INV-DIS
           DISPLAY ' Investimentos ativos: ' WS-INV-CTR
           DISPLAY ' Total da carteira: R$ ' WS-INV-DIS
           DISPLAY '==================================='.

       6000-SIMULAR.
           DISPLAY '--- SIMULADOR DE INVESTIMENTO ---'
           DISPLAY 'Valor inicial: '
           ACCEPT WS-INV-VALOR-APORT
           DISPLAY 'Prazo (dias): '
           ACCEPT WS-PRAZO-DIAS
           PERFORM 2100-CALC-RENTABILIDADE-CDB
           DISPLAY 'SIMULACAO CDB ' WS-PROD-CDB-PERC-CDI '% CDI:'
           MOVE WS-VALOR-LIQUIDO TO WS-VL-DISPLAY
           DISPLAY 'Resultado liquido: R$ ' WS-VL-DISPLAY.

       7000-RELATORIO-RENTAB.
           DISPLAY 'RELATORIO DE RENTABILIDADE'
           DISPLAY 'Gerado em: ' FUNCTION CURRENT-DATE(1:8).

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
