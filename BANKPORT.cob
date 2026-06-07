      *================================================================
      * BANKPORT.COB - Portabilidade (Salario, Credito e Conta)
      * Sistema Bancario COBOL
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKPORT.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQPORT ASSIGN TO 'BANKPORT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS PORT-ID
               FILE STATUS IS FS-PORT.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQPORT.
       01  REG-PORT.
           05  PORT-ID               PIC 9(12).
           05  PORT-CONTA            PIC 9(10).
           05  PORT-TIPO             PIC X(8).
           05  PORT-BANCO-ORIGEM     PIC X(40).
           05  PORT-BANCO-DESTINO    PIC X(40).
           05  PORT-VALOR            PIC S9(11)V99 COMP-3.
           05  PORT-TAXA-ATUAL       PIC 9(3)V99 COMP-3.
           05  PORT-TAXA-NOVA        PIC 9(3)V99 COMP-3.
           05  PORT-DT-SOLICITACAO   PIC 9(8).
           05  PORT-PRAZO-DIAS       PIC 9(2).
           05  PORT-STATUS           PIC X(1).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-PORT-CTRL.
           05  FS-PORT               PIC XX.
               88  FS-PORT-OK        VALUE '00'.
               88  FS-PORT-EOF       VALUE '10'.
               88  FS-PORT-NFD       VALUE '23'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  PORT-PARAR        VALUE 'N'.
           05  WS-PORT-SEQ           PIC 9(12) VALUE ZEROS.

       01  WS-PORT-CALC.
           05  WS-PORT-CONTA-NUM     PIC 9(10).
           05  WS-PORT-ID-SEL        PIC 9(12).
           05  WS-PORT-ECONOMIA-MES  PIC S9(9)V99 COMP-3.
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQPORT
           IF NOT FS-PORT-OK
               OPEN OUTPUT ARQPORT
               CLOSE ARQPORT
               OPEN I-O ARQPORT
           END-IF
           PERFORM 9900-SEQ
           PERFORM 1000-MENU UNTIL PORT-PARAR
           CLOSE ARQPORT
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-SEQ.
           MOVE 999999999999 TO PORT-ID
           START ARQPORT KEY <= PORT-ID
           READ ARQPORT PREVIOUS
           IF FS-PORT-OK
               MOVE PORT-ID TO WS-PORT-SEQ
           ELSE
               MOVE ZEROS TO WS-PORT-SEQ
           END-IF.

      *================================================================
       1000-MENU SECTION.
      *================================================================
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '            PORTABILIDADE'
           DISPLAY '========================================'
           DISPLAY ' 01. Portabilidade de Salario'
           DISPLAY ' 02. Portabilidade de Credito/Emprestimo'
           DISPLAY ' 03. Portabilidade de Conta'
           DISPLAY ' 04. Consultar Solicitacoes'
           DISPLAY ' 05. Cancelar Solicitacao'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-SALARIO
               WHEN '02' PERFORM 3000-CREDITO
               WHEN '03' PERFORM 4000-CONTA
               WHEN '04' PERFORM 5000-CONSULTAR
               WHEN '05' PERFORM 6000-CANCELAR
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

      *================================================================
       2000-SALARIO SECTION.
      *================================================================
       2000-INICIO.
           DISPLAY '--- PORTABILIDADE DE SALARIO ---'
           DISPLAY 'Conta destino (aqui): '
           ACCEPT WS-PORT-CONTA-NUM
           DISPLAY 'Banco de origem do salario: '
           ACCEPT PORT-BANCO-ORIGEM
           DISPLAY 'Empresa empregadora (CNPJ): '
           ACCEPT PORT-BANCO-DESTINO
           ADD 1 TO WS-PORT-SEQ
           MOVE WS-PORT-SEQ TO PORT-ID
           MOVE WS-PORT-CONTA-NUM TO PORT-CONTA
           MOVE 'SALARIO' TO PORT-TIPO
           MOVE ZEROS TO PORT-VALOR PORT-TAXA-ATUAL PORT-TAXA-NOVA
           MOVE 5 TO PORT-PRAZO-DIAS
           MOVE FUNCTION CURRENT-DATE(1:8) TO PORT-DT-SOLICITACAO
           MOVE 'P' TO PORT-STATUS
           WRITE REG-PORT
           IF FS-PORT-OK
               DISPLAY 'SOLICITACAO REGISTRADA! ID: ' PORT-ID
               DISPLAY ' Prazo de efetivacao: ate 5 dias uteis'
               DISPLAY ' Voce recebera instrucoes para informar'
               DISPLAY ' os novos dados bancarios ao RH'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO: ' FS-PORT
               MOVE 9999 TO LS-CODIGO
           END-IF.

      *================================================================
       3000-CREDITO SECTION.
      *================================================================
       3000-INICIO.
           DISPLAY '--- PORTABILIDADE DE CREDITO/EMPRESTIMO ---'
           DISPLAY 'Conta: '
           ACCEPT WS-PORT-CONTA-NUM
           DISPLAY 'Instituicao de origem do contrato: '
           ACCEPT PORT-BANCO-ORIGEM
           DISPLAY 'Saldo devedor a portar (R$): '
           ACCEPT PORT-VALOR
           DISPLAY 'Taxa de juros atual (% a.m.): '
           ACCEPT PORT-TAXA-ATUAL
           MOVE PORT-TAXA-ATUAL TO PORT-TAXA-NOVA
           SUBTRACT 0,30 FROM PORT-TAXA-NOVA
           IF PORT-TAXA-NOVA < 0,50
               MOVE 0,50 TO PORT-TAXA-NOVA
           END-IF
           COMPUTE WS-PORT-ECONOMIA-MES ROUNDED =
               PORT-VALOR * (PORT-TAXA-ATUAL - PORT-TAXA-NOVA) / 100
           MOVE 'CREDITO' TO PORT-BANCO-DESTINO(1:7)
           DISPLAY '========================================'
           DISPLAY ' Taxa atual:        ' PORT-TAXA-ATUAL '% a.m.'
           DISPLAY ' Nossa taxa ofertada:' PORT-TAXA-NOVA '% a.m.'
           MOVE WS-PORT-ECONOMIA-MES TO WS-DIS
           DISPLAY ' Economia estimada/mes: R$ ' WS-DIS
           DISPLAY '========================================'
           DISPLAY 'Confirmar solicitacao de portabilidade? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO NOT = 'S'
               DISPLAY 'OPERACAO ABORTADA'
               EXIT SECTION
           END-IF
           ADD 1 TO WS-PORT-SEQ
           MOVE WS-PORT-SEQ TO PORT-ID
           MOVE WS-PORT-CONTA-NUM TO PORT-CONTA
           MOVE 'CREDITO ' TO PORT-TIPO
           MOVE 10 TO PORT-PRAZO-DIAS
           MOVE FUNCTION CURRENT-DATE(1:8) TO PORT-DT-SOLICITACAO
           MOVE 'P' TO PORT-STATUS
           WRITE REG-PORT
           DISPLAY 'SOLICITACAO REGISTRADA! ID: ' PORT-ID
           MOVE 0 TO LS-CODIGO.

      *================================================================
       4000-CONTA SECTION.
      *================================================================
       4000-INICIO.
           DISPLAY '--- PORTABILIDADE DE CONTA (TROCA DE BANCO) ---'
           DISPLAY 'Conta destino (aqui): '
           ACCEPT WS-PORT-CONTA-NUM
           DISPLAY 'Banco de origem: '
           ACCEPT PORT-BANCO-ORIGEM
           DISPLAY 'Transferir debitos automaticos e PIX? (S/N): '
           ACCEPT WS-OPCAO
           ADD 1 TO WS-PORT-SEQ
           MOVE WS-PORT-SEQ TO PORT-ID
           MOVE WS-PORT-CONTA-NUM TO PORT-CONTA
           MOVE 'CONTA   ' TO PORT-TIPO
           MOVE ZEROS TO PORT-VALOR PORT-TAXA-ATUAL PORT-TAXA-NOVA
           MOVE 7 TO PORT-PRAZO-DIAS
           MOVE FUNCTION CURRENT-DATE(1:8) TO PORT-DT-SOLICITACAO
           MOVE 'P' TO PORT-STATUS
           WRITE REG-PORT
           IF FS-PORT-OK
               DISPLAY 'SOLICITACAO REGISTRADA! ID: ' PORT-ID
               DISPLAY ' Migracao de chaves PIX e debitos: ate 7 dias'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO: ' FS-PORT
               MOVE 9999 TO LS-CODIGO
           END-IF.

      *================================================================
       5000-CONSULTAR SECTION.
      *================================================================
       5000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-PORT-CONTA-NUM
           DISPLAY '========================================'
           DISPLAY ' SOLICITACOES DE PORTABILIDADE'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO PORT-ID
           START ARQPORT KEY >= PORT-ID
           PERFORM UNTIL FS-PORT-EOF
               READ ARQPORT NEXT
               IF FS-PORT-OK
                   IF PORT-CONTA = WS-PORT-CONTA-NUM
                       DISPLAY PORT-ID ' ' PORT-TIPO
                               ' Solicitada em: ' PORT-DT-SOLICITACAO
                       DISPLAY '   Prazo: ' PORT-PRAZO-DIAS
                               ' dias  Status: ' PORT-STATUS
                               ' (P=Pendente A=Aprovada'
                               ' C=Concluida X=Cancelada)'
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       6000-CANCELAR SECTION.
      *================================================================
       6000-INICIO.
           DISPLAY 'ID da Solicitacao: '
           ACCEPT WS-PORT-ID-SEL
           MOVE WS-PORT-ID-SEL TO PORT-ID
           READ ARQPORT KEY IS PORT-ID
           IF FS-PORT-NFD
               DISPLAY 'SOLICITACAO NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF PORT-STATUS = 'C' OR PORT-STATUS = 'X'
               DISPLAY 'SOLICITACAO JA FINALIZADA OU CANCELADA'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Confirmar cancelamento? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'X' TO PORT-STATUS
               REWRITE REG-PORT
               DISPLAY 'SOLICITACAO CANCELADA'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO ABORTADA'
           END-IF.

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
