      *================================================================
      * BANKSCORE.COB - Score de Credito (Analise e Pontuacao)
      * Sistema Bancario COBOL
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKSCORE.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQSCORE ASSIGN TO 'BANKSCORE.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS SCORE-CONTA
               FILE STATUS IS FS-SCORE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQSCORE.
       01  REG-SCORE.
           05  SCORE-CONTA           PIC 9(10).
           05  SCORE-VALOR           PIC 9(4).
           05  SCORE-FAIXA           PIC X(1).
           05  SCORE-FATOR-RENDA     PIC 9(4).
           05  SCORE-FATOR-PONTUAL   PIC 9(4).
           05  SCORE-FATOR-RELACION  PIC 9(4).
           05  SCORE-FATOR-ENDIVID   PIC 9(4).
           05  SCORE-QTD-CONSULTAS   PIC 9(5).
           05  SCORE-DT-ATUALIZ      PIC 9(8).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-SCORE-CTRL.
           05  FS-SCORE              PIC XX.
               88  FS-SCORE-OK       VALUE '00'.
               88  FS-SCORE-EOF      VALUE '10'.
               88  FS-SCORE-NFD      VALUE '23'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  SCORE-PARAR       VALUE 'N'.

       01  WS-SCORE-CALC.
           05  WS-SCORE-CONTA-NUM    PIC 9(10).
           05  WS-SCORE-RENDA        PIC S9(11)V99 COMP-3.
           05  WS-SCORE-DIVIDA-NOVA  PIC S9(11)V99 COMP-3.
           05  WS-SCORE-IMPACTO      PIC S9(5).
           05  WS-SCORE-SIMULADO     PIC S9(5).

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQSCORE
           IF NOT FS-SCORE-OK
               OPEN OUTPUT ARQSCORE
               CLOSE ARQSCORE
               OPEN I-O ARQSCORE
           END-IF
           PERFORM 1000-MENU UNTIL SCORE-PARAR
           CLOSE ARQSCORE
           MOVE 0 TO LS-CODIGO
           GOBACK.

      *================================================================
       1000-MENU SECTION.
      *================================================================
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '       SCORE DE CREDITO'
           DISPLAY '========================================'
           DISPLAY ' 01. Consultar Meu Score'
           DISPLAY ' 02. Calcular / Atualizar Score'
           DISPLAY ' 03. Detalhamento dos Fatores'
           DISPLAY ' 04. Simular Impacto de Nova Divida'
           DISPLAY ' 05. Dicas para Melhorar o Score'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-CONSULTAR
               WHEN '02' PERFORM 3000-CALCULAR
               WHEN '03' PERFORM 4000-DETALHAR
               WHEN '04' PERFORM 5000-SIMULAR-IMPACTO
               WHEN '05' PERFORM 6000-DICAS
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

      *================================================================
       2000-CONSULTAR SECTION.
      *================================================================
       2000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-SCORE-CONTA-NUM
           MOVE WS-SCORE-CONTA-NUM TO SCORE-CONTA
           READ ARQSCORE KEY IS SCORE-CONTA
           IF FS-SCORE-NFD
               DISPLAY 'SCORE AINDA NAO CALCULADO PARA ESTA CONTA'
               DISPLAY 'Utilize a opcao 02 para calcular'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           ADD 1 TO SCORE-QTD-CONSULTAS
           REWRITE REG-SCORE
           DISPLAY '========================================'
           DISPLAY ' SCORE DE CREDITO - CONTA ' SCORE-CONTA
           DISPLAY ' Pontuacao: ' SCORE-VALOR ' / 1000'
           DISPLAY ' Faixa: ' SCORE-FAIXA
           EVALUATE SCORE-FAIXA
               WHEN 'A' DISPLAY ' Classificacao: EXCELENTE (801-1000)'
               WHEN 'B' DISPLAY ' Classificacao: BOM (701-800)'
               WHEN 'C' DISPLAY ' Classificacao: REGULAR (501-700)'
               WHEN 'D' DISPLAY ' Classificacao: BAIXO (301-500)'
               WHEN 'E' DISPLAY ' Classificacao: MUITO BAIXO (0-300)'
           END-EVALUATE
           DISPLAY ' Atualizado em: ' SCORE-DT-ATUALIZ
           DISPLAY ' Consultas realizadas: ' SCORE-QTD-CONSULTAS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       3000-CALCULAR SECTION.
      *================================================================
       3000-INICIO.
           DISPLAY '--- CALCULAR / ATUALIZAR SCORE ---'
           DISPLAY 'Conta: '
           ACCEPT WS-SCORE-CONTA-NUM
           MOVE WS-SCORE-CONTA-NUM TO SCORE-CONTA
           READ ARQSCORE KEY IS SCORE-CONTA
           DISPLAY 'Renda mensal informada (R$): '
           ACCEPT WS-SCORE-RENDA
           DISPLAY 'Pontualidade nos pagamentos (0-100): '
           ACCEPT SCORE-FATOR-PONTUAL
           DISPLAY 'Tempo de relacionamento com o banco (meses): '
           ACCEPT SCORE-FATOR-RELACION
           DISPLAY 'Nivel de endividamento atual (0-100): '
           ACCEPT SCORE-FATOR-ENDIVID
      *    Pontuacao por renda (faixas)
           EVALUATE TRUE
               WHEN WS-SCORE-RENDA >= 10000,00 MOVE 250 TO SCORE-FATOR-RENDA
               WHEN WS-SCORE-RENDA >= 5000,00  MOVE 200 TO SCORE-FATOR-RENDA
               WHEN WS-SCORE-RENDA >= 2000,00  MOVE 150 TO SCORE-FATOR-RENDA
               WHEN OTHER                      MOVE 100 TO SCORE-FATOR-RENDA
           END-EVALUATE
      *    Composicao do score (pesos): renda 25%, pontualidade 35%,
      *    relacionamento 15% (capado em 60 meses), endividamento 25% (inverso)
           COMPUTE SCORE-VALOR =
               SCORE-FATOR-RENDA
               + (SCORE-FATOR-PONTUAL * 3,5)
               + (FUNCTION MIN(SCORE-FATOR-RELACION, 60) * 2,5)
               + ((100 - SCORE-FATOR-ENDIVID) * 2,5)
           IF SCORE-VALOR > 1000
               MOVE 1000 TO SCORE-VALOR
           END-IF
           EVALUATE TRUE
               WHEN SCORE-VALOR > 800 MOVE 'A' TO SCORE-FAIXA
               WHEN SCORE-VALOR > 700 MOVE 'B' TO SCORE-FAIXA
               WHEN SCORE-VALOR > 500 MOVE 'C' TO SCORE-FAIXA
               WHEN SCORE-VALOR > 300 MOVE 'D' TO SCORE-FAIXA
               WHEN OTHER             MOVE 'E' TO SCORE-FAIXA
           END-EVALUATE
           MOVE FUNCTION CURRENT-DATE(1:8) TO SCORE-DT-ATUALIZ
           IF FS-SCORE-OK
               REWRITE REG-SCORE
           ELSE
               MOVE ZEROS TO SCORE-QTD-CONSULTAS
               WRITE REG-SCORE
           END-IF
           DISPLAY 'SCORE CALCULADO: ' SCORE-VALOR
                   ' (Faixa ' SCORE-FAIXA ')'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       4000-DETALHAR SECTION.
      *================================================================
       4000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-SCORE-CONTA-NUM
           MOVE WS-SCORE-CONTA-NUM TO SCORE-CONTA
           READ ARQSCORE KEY IS SCORE-CONTA
           IF FS-SCORE-NFD
               DISPLAY 'SCORE AINDA NAO CALCULADO PARA ESTA CONTA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY '========================================'
           DISPLAY ' FATORES QUE COMPOEM O SCORE'
           DISPLAY '----------------------------------------'
           DISPLAY ' Faixa de renda:        ' SCORE-FATOR-RENDA ' pts'
           DISPLAY ' Pontualidade:          ' SCORE-FATOR-PONTUAL '/100'
           DISPLAY ' Relacionamento (mes):  ' SCORE-FATOR-RELACION
           DISPLAY ' Endividamento:         ' SCORE-FATOR-ENDIVID '/100'
           DISPLAY '----------------------------------------'
           DISPLAY ' SCORE FINAL: ' SCORE-VALOR ' / 1000'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       5000-SIMULAR-IMPACTO SECTION.
      *================================================================
       5000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-SCORE-CONTA-NUM
           MOVE WS-SCORE-CONTA-NUM TO SCORE-CONTA
           READ ARQSCORE KEY IS SCORE-CONTA
           IF FS-SCORE-NFD
               DISPLAY 'SCORE AINDA NAO CALCULADO PARA ESTA CONTA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Valor da nova divida/emprestimo pretendido (R$): '
           ACCEPT WS-SCORE-DIVIDA-NOVA
      *    Impacto estimado: reduz score proporcionalmente ao valor
           COMPUTE WS-SCORE-IMPACTO =
               (WS-SCORE-DIVIDA-NOVA / 1000) * 5
           IF WS-SCORE-IMPACTO > 150
               MOVE 150 TO WS-SCORE-IMPACTO
           END-IF
           COMPUTE WS-SCORE-SIMULADO = SCORE-VALOR - WS-SCORE-IMPACTO
           IF WS-SCORE-SIMULADO < 0
               MOVE 0 TO WS-SCORE-SIMULADO
           END-IF
           DISPLAY '========================================'
           DISPLAY ' Score atual:        ' SCORE-VALOR
           DISPLAY ' Impacto estimado:  -' WS-SCORE-IMPACTO ' pts'
           DISPLAY ' Score apos contratacao (estimado): '
                   WS-SCORE-SIMULADO
           DISPLAY ' (O score se recupera com pagamentos em dia)'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       6000-DICAS SECTION.
      *================================================================
       6000-INICIO.
           DISPLAY '========================================'
           DISPLAY ' DICAS PARA MELHORAR SEU SCORE'
           DISPLAY '----------------------------------------'
           DISPLAY ' 1. Pague suas contas em dia'
           DISPLAY ' 2. Mantenha o uso do limite abaixo de 30%'
           DISPLAY ' 3. Evite multiplas solicitacoes de credito'
           DISPLAY ' 4. Mantenha relacionamento de longo prazo'
           DISPLAY ' 5. Negocie e quite dividas em atraso'
           DISPLAY ' 6. Mantenha dados cadastrais atualizados'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
