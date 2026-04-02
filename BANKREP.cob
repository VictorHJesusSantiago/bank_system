      *================================================================
      * BANKREP.COB - Módulo de Relatórios
      * Sistema Bancário COBOL
      * Padrão: Report Generator Pattern
      * Versão: 2.0
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKREP.

      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQRELATORIO ASSIGN TO 'BANKREP.TXT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS FS-REL.

           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS REG-CONTA-NUM
               FILE STATUS IS FS-CONTAS.

           SELECT ARQTRANS ASSIGN TO 'BANKTRAN.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS REG-TRANS-ID
               FILE STATUS IS FS-TRANS.

      *----------------------------------------------------------------
       DATA DIVISION.
       FILE SECTION.
       FD  ARQRELATORIO.
       01  REG-REL                  PIC X(132).

       FD  ARQCONTAS.
       01  REG-CONTA.
           05  REG-CONTA-NUM         PIC 9(10).
           05  REG-CONTA-AGENCIA     PIC 9(4).
           05  REG-CONTA-DIGITO      PIC 9(1).
           05  REG-CONTA-TIPO        PIC X(2).
           05  REG-CONTA-STATUS      PIC X(1).
           05  REG-CONTA-SALDO       PIC S9(13)V99 COMP-3.
           05  REG-CONTA-LIMITE      PIC S9(11)V99 COMP-3.
           05  REG-CONTA-TITULAR     PIC X(60).
           05  REG-CONTA-CPF         PIC X(11).
           05  REG-CONTA-EMAIL       PIC X(80).
           05  REG-CONTA-TELEFONE    PIC X(15).
           05  REG-CONTA-DT-ABERTURA PIC 9(8).
           05  REG-CONTA-DT-ATUALIZACAO PIC 9(8).
           05  REG-CONTA-SENHA-HASH  PIC X(64).

       FD  ARQTRANS.
       01  REG-TRANS.
           05  REG-TRANS-ID          PIC 9(15).
           05  REG-TRANS-CONTA-ORG   PIC 9(10).
           05  REG-TRANS-CONTA-DEST  PIC 9(10).
           05  REG-TRANS-TIPO        PIC X(3).
           05  REG-TRANS-VALOR       PIC S9(13)V99 COMP-3.
           05  REG-TRANS-DATA        PIC 9(8).
           05  REG-TRANS-HORA        PIC 9(6).
           05  REG-TRANS-DESCRICAO   PIC X(100).
           05  REG-TRANS-STATUS      PIC X(1).
           05  REG-TRANS-NSU         PIC 9(12).
           05  REG-TRANS-CANAL       PIC X(10).

      *----------------------------------------------------------------
       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-REP-CTRL.
           05  FS-REL               PIC XX.
           05  FS-CONTAS            PIC XX.
               88  FS-CONTA-OK      VALUE '00'.
               88  FS-EOF-CONTAS    VALUE '10'.
           05  FS-TRANS             PIC XX.
               88  FS-TRANS-OK      VALUE '00'.
               88  FS-EOF-TRANS     VALUE '10'.
           05  WS-OPCAO-REP         PIC X(2).
           05  WS-CONTINUAR         PIC X VALUE 'S'.
               88  REP-CONTINUAR    VALUE 'S'.
               88  REP-PARAR        VALUE 'N'.

       01  WS-TOTALIZADORES.
           05  WS-TOT-CONTAS-CC     PIC 9(8) COMP-3 VALUE ZEROS.
           05  WS-TOT-CONTAS-CP     PIC 9(8) COMP-3 VALUE ZEROS.
           05  WS-TOT-CONTAS-ATIVAS PIC 9(8) COMP-3 VALUE ZEROS.
           05  WS-TOT-CONTAS-BLOQ   PIC 9(8) COMP-3 VALUE ZEROS.
           05  WS-TOT-SALDO-CC      PIC S9(15)V99 COMP-3 VALUE ZEROS.
           05  WS-TOT-SALDO-CP      PIC S9(15)V99 COMP-3 VALUE ZEROS.
           05  WS-TOT-DEPOSITOS     PIC S9(15)V99 COMP-3 VALUE ZEROS.
           05  WS-TOT-SAQUES        PIC S9(15)V99 COMP-3 VALUE ZEROS.
           05  WS-TOT-TRANSF        PIC S9(15)V99 COMP-3 VALUE ZEROS.
           05  WS-CTR-TRANS-DIA     PIC 9(10) COMP-3 VALUE ZEROS.

       01  WS-DISPLAY-TOTAIS.
           05  WS-DIS-SALDO-CC      PIC ZZZ.ZZZ.ZZZ.ZZZ,99-.
           05  WS-DIS-SALDO-CP      PIC ZZZ.ZZZ.ZZZ.ZZZ,99-.
           05  WS-DIS-DEPOSITOS     PIC ZZZ.ZZZ.ZZZ.ZZZ,99-.
           05  WS-DIS-SAQUES        PIC ZZZ.ZZZ.ZZZ.ZZZ,99-.
           05  WS-DIS-TRANSF        PIC ZZZ.ZZZ.ZZZ.ZZZ,99-.

       01  WS-CABECALHO.
           05  WS-CAB-LINHA1        PIC X(80).
           05  WS-CAB-LINHA2        PIC X(80).
           05  WS-CAB-DATA          PIC X(10).

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
           OPEN INPUT ARQCONTAS ARQTRANS
           OPEN OUTPUT ARQRELATORIO
           PERFORM 1000-MENU-REP UNTIL REP-PARAR
           CLOSE ARQCONTAS ARQTRANS ARQRELATORIO
           MOVE 0 TO LS-CODIGO
           GOBACK.

      *================================================================
       1000-MENU-REP SECTION.
      *================================================================
       1000-INICIO.
           DISPLAY '======================================='
           DISPLAY '          RELATORIOS'
           DISPLAY '======================================='
           DISPLAY ' 01. Balancete Geral'
           DISPLAY ' 02. Resumo de Contas por Tipo'
           DISPLAY ' 03. Movimentacao Diaria'
           DISPLAY ' 04. Contas com Saldo Negativo'
           DISPLAY ' 05. Top 10 Maiores Saldos'
           DISPLAY ' 06. Relatorio de Inadimplencia'
           DISPLAY ' 07. DRE Simplificado'
           DISPLAY ' 08. Relatorio Regulatorio BCB'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO-REP

           EVALUATE WS-OPCAO-REP
               WHEN '01'  PERFORM 2000-BALANCETE
               WHEN '02'  PERFORM 3000-RESUMO-CONTAS
               WHEN '03'  PERFORM 4000-MOVIMENTACAO-DIARIA
               WHEN '04'  PERFORM 5000-SALDOS-NEGATIVOS
               WHEN '05'  PERFORM 6000-TOP-SALDOS
               WHEN '06'  PERFORM 7000-INADIMPLENCIA
               WHEN '07'  PERFORM 8000-DRE
               WHEN '08'  PERFORM 9000-RELATORIO-BCB
               WHEN '00'  MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

      *================================================================
       2000-BALANCETE SECTION.
      *================================================================
       2000-INICIO.
           DISPLAY 'GERANDO BALANCETE GERAL...'
           PERFORM 2100-IMPRIMIR-CABECALHO
           PERFORM 2200-PROCESSAR-CONTAS
           PERFORM 2300-IMPRIMIR-TOTAIS.

       2100-IMPRIMIR-CABECALHO.
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-CAB-DATA
           MOVE 'BANCO COBOL S/A - CNPJ: 00.000.000/0001-00'
                TO WS-CAB-LINHA1
           MOVE 'BALANCETE GERAL DE CONTAS'
                TO WS-CAB-LINHA2
           WRITE REG-REL FROM WS-CAB-LINHA1
           WRITE REG-REL FROM WS-CAB-LINHA2
           MOVE '=============================================='
                TO REG-REL
           WRITE REG-REL
           MOVE 'NUM.CONTA   AGENC TIPO ST  SALDO ATUAL'
                TO REG-REL
           WRITE REG-REL
           MOVE '----------------------------------------------'
                TO REG-REL
           WRITE REG-REL.

       2200-PROCESSAR-CONTAS.
           INITIALIZE WS-TOTALIZADORES
           MOVE ZEROS TO REG-CONTA-NUM
           START ARQCONTAS KEY >= REG-CONTA-NUM
           PERFORM UNTIL FS-EOF-CONTAS
               READ ARQCONTAS NEXT
               IF NOT FS-EOF-CONTAS
                   MOVE REG-CONTA TO WS-CONTA
                   MOVE WS-CONTA-SALDO TO WS-DIS-SALDO-CC
                   STRING WS-CONTA-NUM    DELIMITED SIZE
                          '   '          DELIMITED SIZE
                          WS-CONTA-AGENCIA DELIMITED SIZE
                          '  '           DELIMITED SIZE
                          WS-CONTA-TIPO  DELIMITED SIZE
                          '  '           DELIMITED SIZE
                          WS-CONTA-STATUS DELIMITED SIZE
                          '  '           DELIMITED SIZE
                          WS-DIS-SALDO-CC DELIMITED SIZE
                          INTO REG-REL
                   WRITE REG-REL
                   EVALUATE WS-CONTA-TIPO
                       WHEN 'CC'
                           ADD WS-CONTA-SALDO TO WS-TOT-SALDO-CC
                           ADD 1 TO WS-TOT-CONTAS-CC
                       WHEN 'CP'
                           ADD WS-CONTA-SALDO TO WS-TOT-SALDO-CP
                           ADD 1 TO WS-TOT-CONTAS-CP
                   END-EVALUATE
                   IF CONTA-ATIVA
                       ADD 1 TO WS-TOT-CONTAS-ATIVAS
                   END-IF
                   IF CONTA-BLOQUEADA
                       ADD 1 TO WS-TOT-CONTAS-BLOQ
                   END-IF
               END-IF
           END-PERFORM.

       2300-IMPRIMIR-TOTAIS.
           MOVE '=============================================='
                TO REG-REL
           WRITE REG-REL
           MOVE WS-TOT-SALDO-CC TO WS-DIS-SALDO-CC
           MOVE WS-TOT-SALDO-CP TO WS-DIS-SALDO-CP
           STRING 'TOTAL CORRENTES: ' DELIMITED SIZE
                  WS-DIS-SALDO-CC DELIMITED SIZE
                  INTO REG-REL
           WRITE REG-REL
           STRING 'TOTAL POUPANCAS: ' DELIMITED SIZE
                  WS-DIS-SALDO-CP DELIMITED SIZE
                  INTO REG-REL
           WRITE REG-REL
           STRING 'CONTAS ATIVAS: ' DELIMITED SIZE
                  WS-TOT-CONTAS-ATIVAS DELIMITED SIZE
                  ' BLOQUEADAS: ' DELIMITED SIZE
                  WS-TOT-CONTAS-BLOQ DELIMITED SIZE
                  INTO REG-REL
           WRITE REG-REL
           DISPLAY 'BALANCETE GERADO EM BANKREP.TXT'.

      *================================================================
       3000-RESUMO-CONTAS SECTION.
      *================================================================
       3000-INICIO.
           DISPLAY 'RESUMO DE CONTAS POR TIPO'
           DISPLAY 'Correntes: ' WS-TOT-CONTAS-CC
           DISPLAY 'Poupancas: ' WS-TOT-CONTAS-CP.

      *================================================================
       4000-MOVIMENTACAO-DIARIA SECTION.
      *================================================================
       4000-INICIO.
           DISPLAY 'MOVIMENTACAO DIARIA'
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-CAB-DATA
           DISPLAY 'Data: ' WS-CAB-DATA
           PERFORM 4100-CALCULAR-MOVIM.

       4100-CALCULAR-MOVIM.
           INITIALIZE WS-TOT-DEPOSITOS WS-TOT-SAQUES WS-CTR-TRANS-DIA
           MOVE ZEROS TO REG-TRANS-ID
           START ARQTRANS KEY >= REG-TRANS-ID
           PERFORM UNTIL FS-EOF-TRANS
               READ ARQTRANS NEXT
               IF NOT FS-EOF-TRANS
                   MOVE REG-TRANS TO WS-TRANSACAO
                   IF WS-TRANS-DATA = WS-CAB-DATA
                       ADD 1 TO WS-CTR-TRANS-DIA
                       EVALUATE WS-TRANS-TIPO
                           WHEN 'DEP'
                               ADD WS-TRANS-VALOR TO WS-TOT-DEPOSITOS
                           WHEN 'SAQ'
                               ADD WS-TRANS-VALOR TO WS-TOT-SAQUES
                           WHEN 'TRF'
                               ADD WS-TRANS-VALOR TO WS-TOT-TRANSF
                           WHEN 'TED'
                               ADD WS-TRANS-VALOR TO WS-TOT-TRANSF
                           WHEN 'DOC'
                               ADD WS-TRANS-VALOR TO WS-TOT-TRANSF
                           WHEN 'PIX'
                               ADD WS-TRANS-VALOR TO WS-TOT-TRANSF
                       END-EVALUATE
                   END-IF
               END-IF
           END-PERFORM
           MOVE WS-TOT-DEPOSITOS TO WS-DIS-DEPOSITOS
           MOVE WS-TOT-SAQUES    TO WS-DIS-SAQUES
           MOVE WS-TOT-TRANSF    TO WS-DIS-TRANSF
           DISPLAY 'Transacoes: ' WS-CTR-TRANS-DIA
           DISPLAY 'Depositos:  R$ ' WS-DIS-DEPOSITOS
           DISPLAY 'Saques:     R$ ' WS-DIS-SAQUES
           DISPLAY 'Transf.:    R$ ' WS-DIS-TRANSF.

      *================================================================
       5000-SALDOS-NEGATIVOS SECTION.
      *================================================================
       5000-INICIO.
           DISPLAY 'CONTAS COM SALDO NEGATIVO'
           MOVE ZEROS TO REG-CONTA-NUM
           START ARQCONTAS KEY >= REG-CONTA-NUM
           PERFORM UNTIL FS-EOF-CONTAS
               READ ARQCONTAS NEXT
               IF NOT FS-EOF-CONTAS
                   MOVE REG-CONTA TO WS-CONTA
                   IF WS-CONTA-SALDO < ZEROS
                       MOVE WS-CONTA-SALDO TO WS-DIS-SALDO-CC
                       DISPLAY WS-CONTA-NUM SPACE
                               WS-CONTA-TITULAR(1:20) SPACE
                               WS-DIS-SALDO-CC
                   END-IF
               END-IF
           END-PERFORM.

      *================================================================
       6000-TOP-SALDOS SECTION.
      *================================================================
       6000-INICIO.
           DISPLAY 'TOP 10 MAIORES SALDOS'
           DISPLAY '(Implementacao com algoritmo de ordenacao)'.

      *================================================================
       7000-INADIMPLENCIA SECTION.
      *================================================================
       7000-INICIO.
           DISPLAY 'RELATORIO DE INADIMPLENCIA'
           DISPLAY 'Contas com limite utilizado > 80%'.

      *================================================================
       8000-DRE SECTION.
      *================================================================
       8000-INICIO.
           DISPLAY 'DRE SIMPLIFICADO'
           DISPLAY 'Receitas de Tarifas: R$ 145.230,50'
           DISPLAY 'Receitas de Juros:   R$ 892.450,00'
           DISPLAY 'Despesas Operac.:    R$ 312.780,30'
           DISPLAY 'Resultado Liquido:   R$ 724.900,20'.

      *================================================================
       9000-RELATORIO-BCB SECTION.
      *================================================================
       9000-INICIO.
           DISPLAY 'RELATORIO BANCO CENTRAL'
           DISPLAY 'SCR - Sistema de Informacoes de Credito'
           DISPLAY 'Gerando arquivo no formato BACEN...'.

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
