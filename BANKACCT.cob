      *================================================================
      * BANKACCT.COB - Módulo de Gestão de Contas
      * Sistema Bancário COBOL
      * Padrão: Repository Pattern + Business Rules Layer
      * Versão: 2.0
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKACCT.

      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS REG-CONTA-NUM
               ALTERNATE RECORD KEY IS REG-CONTA-CPF WITH DUPLICATES
               FILE STATUS IS FS-CONTAS.

      *----------------------------------------------------------------
       DATA DIVISION.
       FILE SECTION.
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

      *----------------------------------------------------------------
       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-ACCT-CTRL.
           05  FS-CONTAS            PIC XX.
               88  FS-OK            VALUE '00'.
               88  FS-EOF           VALUE '10'.
               88  FS-DUPLICADO     VALUE '22'.
               88  FS-NAO-ENCONTRADO VALUE '23'.
           05  WS-OPCAO-ACCT        PIC X(2).
           05  WS-NOVO-NUM          PIC 9(10).
           05  WS-CONTINUAR         PIC X VALUE 'S'.
               88  ACCT-CONTINUAR   VALUE 'S'.
               88  ACCT-PARAR       VALUE 'N'.
           05  WS-CTR-CONTAS        PIC 9(8) VALUE ZEROS.
           05  WS-TOTAL-SALDOS      PIC S9(15)V99 COMP-3 VALUE ZEROS.
           05  WS-DATA-ATUAL        PIC 9(8).

       01  WS-DISPLAY-CONTA.
           05  WS-SALDO-DISPLAY     PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-LIMITE-DISPLAY    PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-NUM-DISPLAY       PIC 9999999999.

       01  WS-VALIDACAO.
           05  WS-CPF-VALIDO        PIC X VALUE 'N'.
           05  WS-DIGITO-CALC       PIC 9(4) COMP-3.
           05  WS-SOMA-CPF          PIC 9(6) COMP-3.
           05  WS-IDX               PIC 9(2) COMP-3.
           05  WS-RESTO             PIC 9(2) COMP-3.

       01  WS-REGRAS-NEGOCIO.
           05  WS-SALDO-MIN-CC      PIC S9(9)V99 COMP-3 VALUE -500,00.
           05  WS-SALDO-MIN-CP      PIC S9(9)V99 COMP-3 VALUE 0,00.
           05  WS-LIMITE-MAX        PIC S9(11)V99 COMP-3 VALUE 50000,00.
           05  WS-TAXA-MANUT        PIC 9(3)V99 COMP-3 VALUE 12,90.

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
           OPEN I-O ARQCONTAS
           PERFORM 1000-MENU-CONTAS UNTIL ACCT-PARAR
           CLOSE ARQCONTAS
           MOVE 0 TO LS-CODIGO
           GOBACK.

      *================================================================
       1000-MENU-CONTAS SECTION.
      *================================================================
       1000-INICIO.
           DISPLAY '======================================='
           DISPLAY '      GESTAO DE CONTAS'
           DISPLAY '======================================='
           DISPLAY ' 01. Abrir Nova Conta'
           DISPLAY ' 02. Consultar Conta'
           DISPLAY ' 03. Atualizar Dados'
           DISPLAY ' 04. Bloquear/Desbloquear Conta'
           DISPLAY ' 05. Encerrar Conta'
           DISPLAY ' 06. Listar Todas as Contas'
           DISPLAY ' 07. Buscar por CPF'
           DISPLAY ' 08. Aplicar Tarifa de Manutencao'
           DISPLAY ' 09. Relatorio de Contas'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO-ACCT

           EVALUATE WS-OPCAO-ACCT
               WHEN '01'  PERFORM 2000-ABRIR-CONTA
               WHEN '02'  PERFORM 3000-CONSULTAR-CONTA
               WHEN '03'  PERFORM 4000-ATUALIZAR-CONTA
               WHEN '04'  PERFORM 5000-BLOQ-DESBLOQ-CONTA
               WHEN '05'  PERFORM 6000-ENCERRAR-CONTA
               WHEN '06'  PERFORM 7000-LISTAR-CONTAS
               WHEN '07'  PERFORM 8000-BUSCAR-POR-CPF
               WHEN '08'  PERFORM 8500-APLICAR-TARIFAS
               WHEN '09'  PERFORM 8800-RELATORIO-CONTAS
               WHEN '00'  MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER
                   DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

      *================================================================
       2000-ABRIR-CONTA SECTION.
      *================================================================
       2000-INICIO.
           DISPLAY '--- ABERTURA DE CONTA ---'
           PERFORM 2100-COLETAR-DADOS
           PERFORM 2200-VALIDAR-DADOS
           IF WS-CPF-VALIDO = 'S'
               PERFORM 2300-VERIFICAR-DUPLICIDADE
               PERFORM 2400-GERAR-NUMERO-CONTA
               PERFORM 2500-GRAVAR-CONTA
               PERFORM 2600-EXIBIR-CONFIRMACAO
           ELSE
               DISPLAY 'CPF INVALIDO - OPERACAO CANCELADA'
               MOVE 0001 TO LS-CODIGO
           END-IF.

       2100-COLETAR-DADOS.
           INITIALIZE WS-CONTA
           DISPLAY 'Nome do Titular: '
           ACCEPT WS-CONTA-TITULAR
           DISPLAY 'CPF (somente numeros): '
           ACCEPT WS-CONTA-CPF
            DISPLAY 'Tipo: CC/CP/CS/CI'
           ACCEPT WS-CONTA-TIPO
           DISPLAY 'Agencia (4 digitos): '
           ACCEPT WS-CONTA-AGENCIA
           DISPLAY 'Email: '
           ACCEPT WS-CONTA-EMAIL
           DISPLAY 'Telefone: '
           ACCEPT WS-CONTA-TELEFONE.

       2200-VALIDAR-DADOS.
           PERFORM 2210-VALIDAR-CPF
           PERFORM 2220-VALIDAR-TIPO-CONTA.

       2210-VALIDAR-CPF.
      *    Algoritmo de validacao de CPF
           MOVE 'S' TO WS-CPF-VALIDO
           MOVE ZEROS TO WS-SOMA-CPF

      *    Calcula primeiro digito verificador
           MOVE 0 TO WS-SOMA-CPF
           PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > 9
               COMPUTE WS-SOMA-CPF = WS-SOMA-CPF +
                   (FUNCTION NUMVAL(WS-CONTA-CPF(WS-IDX:1)) *
                   (11 - WS-IDX))
           END-PERFORM
           COMPUTE WS-RESTO = FUNCTION MOD(WS-SOMA-CPF 11)
           IF WS-RESTO < 2
               MOVE 0 TO WS-DIGITO-CALC
           ELSE
               COMPUTE WS-DIGITO-CALC = 11 - WS-RESTO
           END-IF
           IF WS-DIGITO-CALC NOT = FUNCTION NUMVAL(WS-CONTA-CPF(10:1))
               MOVE 'N' TO WS-CPF-VALIDO
           END-IF.

       2220-VALIDAR-TIPO-CONTA.
           IF NOT (CONTA-CORRENTE OR CONTA-POUPANCA OR
                   CONTA-SALARIO OR CONTA-INVESTIMENTO)
               MOVE 'CC' TO WS-CONTA-TIPO
           END-IF.

       2300-VERIFICAR-DUPLICIDADE.
           MOVE WS-CONTA-CPF TO REG-CONTA-CPF
           READ ARQCONTAS KEY IS REG-CONTA-CPF
           IF FS-OK
               DISPLAY 'ATENCAO: CPF ja possui conta ativa'
           END-IF.

       2400-GERAR-NUMERO-CONTA.
      *    Gera numero sequencial unico
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-DATA-ATUAL
           COMPUTE WS-NOVO-NUM = WS-DATA-ATUAL * 100 +
                                 WS-CTR-CONTAS
           MOVE WS-NOVO-NUM TO WS-CONTA-NUM
      *    Calcula digito verificador da conta
           COMPUTE WS-CONTA-DIGITO =
               FUNCTION MOD(WS-CONTA-NUM 10)
           ADD 1 TO WS-CTR-CONTAS.

       2500-GRAVAR-CONTA.
           MOVE 'A' TO WS-CONTA-STATUS
           MOVE ZEROS TO WS-CONTA-SALDO
           IF CONTA-CORRENTE
               MOVE -500,00 TO WS-CONTA-LIMITE
           ELSE
               MOVE ZEROS TO WS-CONTA-LIMITE
           END-IF
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-CONTA-DT-ABERTURA
           MOVE WS-CONTA TO REG-CONTA
           WRITE REG-CONTA
           IF FS-OK
               MOVE 0 TO LS-CODIGO
               DISPLAY 'CONTA CRIADA COM SUCESSO!'
           ELSE
               MOVE 9999 TO LS-CODIGO
               DISPLAY 'ERRO AO CRIAR CONTA: ' FS-CONTAS
           END-IF.

       2600-EXIBIR-CONFIRMACAO.
           DISPLAY '================================='
           DISPLAY 'CONTA ABERTA COM SUCESSO!'
           DISPLAY 'Numero: ' WS-CONTA-NUM
           DISPLAY 'Agencia: ' WS-CONTA-AGENCIA
           DISPLAY 'Digito: ' WS-CONTA-DIGITO
           DISPLAY 'Titular: ' WS-CONTA-TITULAR
           DISPLAY 'Tipo: ' WS-CONTA-TIPO
           DISPLAY '================================='.

      *================================================================
       3000-CONSULTAR-CONTA SECTION.
      *================================================================
       3000-INICIO.
           DISPLAY 'Numero da Conta: '
           ACCEPT WS-CONTA-NUM
           MOVE WS-CONTA-NUM TO REG-CONTA-NUM
           READ ARQCONTAS KEY IS REG-CONTA-NUM
           IF FS-NAO-ENCONTRADO
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 0002 TO LS-CODIGO
           ELSE IF FS-OK
               MOVE REG-CONTA TO WS-CONTA
               PERFORM 3100-EXIBIR-CONTA
           ELSE
               DISPLAY 'ERRO NA LEITURA: ' FS-CONTAS
               MOVE 9999 TO LS-CODIGO
           END-IF.

       3100-EXIBIR-CONTA.
           MOVE WS-CONTA-SALDO TO WS-SALDO-DISPLAY
           MOVE WS-CONTA-LIMITE TO WS-LIMITE-DISPLAY
           DISPLAY '================================='
           DISPLAY 'DADOS DA CONTA'
           DISPLAY 'Numero: ' WS-CONTA-NUM
           DISPLAY 'Agencia: ' WS-CONTA-AGENCIA '-' WS-CONTA-DIGITO
           DISPLAY 'Titular: ' WS-CONTA-TITULAR
           DISPLAY 'CPF: ' WS-CONTA-CPF
           DISPLAY 'Tipo: ' WS-CONTA-TIPO
           DISPLAY 'Status: ' WS-CONTA-STATUS
           DISPLAY 'Saldo: R$ ' WS-SALDO-DISPLAY
           DISPLAY 'Limite: R$ ' WS-LIMITE-DISPLAY
           DISPLAY 'Email: ' WS-CONTA-EMAIL
           DISPLAY 'Telefone: ' WS-CONTA-TELEFONE
           DISPLAY 'Abertura: ' WS-CONTA-DT-ABERTURA
           DISPLAY '================================='.

      *================================================================
       4000-ATUALIZAR-CONTA SECTION.
      *================================================================
       4000-INICIO.
           DISPLAY 'Numero da Conta para Atualizar: '
           ACCEPT WS-CONTA-NUM
           MOVE WS-CONTA-NUM TO REG-CONTA-NUM
           READ ARQCONTAS KEY IS REG-CONTA-NUM
           IF FS-NAO-ENCONTRADO
               DISPLAY 'CONTA NAO ENCONTRADA'
           ELSE IF FS-OK
               MOVE REG-CONTA TO WS-CONTA
               PERFORM 4100-ATUALIZAR-DADOS
               PERFORM 4200-GRAVAR-ATUALIZACAO
           END-IF.

       4100-ATUALIZAR-DADOS.
           DISPLAY 'Novo Email (ENTER para manter): '
           ACCEPT WS-CONTA-EMAIL
           DISPLAY 'Novo Telefone (ENTER para manter): '
           ACCEPT WS-CONTA-TELEFONE
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-CONTA-DT-ATUALIZACAO.

       4200-GRAVAR-ATUALIZACAO.
           MOVE WS-CONTA TO REG-CONTA
           REWRITE REG-CONTA
           IF FS-OK
               DISPLAY 'DADOS ATUALIZADOS COM SUCESSO!'
           ELSE
               DISPLAY 'ERRO AO ATUALIZAR: ' FS-CONTAS
           END-IF.

      *================================================================
       5000-BLOQ-DESBLOQ-CONTA SECTION.
      *================================================================
       5000-INICIO.
           DISPLAY 'Numero da Conta: '
           ACCEPT WS-CONTA-NUM
           MOVE WS-CONTA-NUM TO REG-CONTA-NUM
           READ ARQCONTAS KEY IS REG-CONTA-NUM
           IF FS-NAO-ENCONTRADO
               DISPLAY 'CONTA NAO ENCONTRADA'
           ELSE IF FS-OK
               MOVE REG-CONTA TO WS-CONTA
               EVALUATE WS-CONTA-STATUS
                   WHEN 'A'
                       MOVE 'B' TO WS-CONTA-STATUS
                       DISPLAY 'CONTA BLOQUEADA!'
                   WHEN 'B'
                       MOVE 'A' TO WS-CONTA-STATUS
                       DISPLAY 'CONTA DESBLOQUEADA!'
                   WHEN 'E'
                        DISPLAY 'CONTA ENCERRADA - SEM REATIVACAO'
                   WHEN OTHER
                       DISPLAY 'STATUS INVALIDO'
               END-EVALUATE
               PERFORM 4200-GRAVAR-ATUALIZACAO
           END-IF.

      *================================================================
       6000-ENCERRAR-CONTA SECTION.
      *================================================================
       6000-INICIO.
           DISPLAY 'Numero da Conta para Encerrar: '
           ACCEPT WS-CONTA-NUM
           MOVE WS-CONTA-NUM TO REG-CONTA-NUM
           READ ARQCONTAS KEY IS REG-CONTA-NUM
           IF FS-OK
               MOVE REG-CONTA TO WS-CONTA
               IF WS-CONTA-SALDO NOT = ZEROS
                   DISPLAY 'CONTA POSSUI SALDO - ZERE ANTES DE ENCERRAR'
                   MOVE 0003 TO LS-CODIGO
               ELSE
                   MOVE 'E' TO WS-CONTA-STATUS
                   MOVE WS-CONTA TO REG-CONTA
                   REWRITE REG-CONTA
                   DISPLAY 'CONTA ENCERRADA COM SUCESSO!'
               END-IF
           END-IF.

      *================================================================
       7000-LISTAR-CONTAS SECTION.
      *================================================================
       7000-INICIO.
           MOVE ZEROS TO WS-CTR-CONTAS
           MOVE ZEROS TO WS-TOTAL-SALDOS
           MOVE ZEROS TO REG-CONTA-NUM
           START ARQCONTAS KEY >= REG-CONTA-NUM
           PERFORM UNTIL FS-EOF
               READ ARQCONTAS NEXT
               IF NOT FS-EOF
                   MOVE REG-CONTA TO WS-CONTA
                   MOVE WS-CONTA-SALDO TO WS-SALDO-DISPLAY
                   DISPLAY WS-CONTA-NUM SPACE
                           WS-CONTA-AGENCIA SPACE
                           WS-CONTA-TITULAR(1:20) SPACE
                           WS-CONTA-TIPO SPACE
                           WS-CONTA-STATUS SPACE
                           WS-SALDO-DISPLAY
                   ADD 1 TO WS-CTR-CONTAS
                   ADD WS-CONTA-SALDO TO WS-TOTAL-SALDOS
               END-IF
           END-PERFORM
           DISPLAY 'Total de Contas: ' WS-CTR-CONTAS
           MOVE WS-TOTAL-SALDOS TO WS-SALDO-DISPLAY
           DISPLAY 'Saldo Total: R$ ' WS-SALDO-DISPLAY.

      *================================================================
       8000-BUSCAR-POR-CPF SECTION.
      *================================================================
       8000-INICIO.
           DISPLAY 'CPF (somente numeros): '
           ACCEPT WS-CONTA-CPF
           MOVE WS-CONTA-CPF TO REG-CONTA-CPF
           READ ARQCONTAS KEY IS REG-CONTA-CPF
           IF FS-OK
               MOVE REG-CONTA TO WS-CONTA
               PERFORM 3100-EXIBIR-CONTA
           ELSE
               DISPLAY 'NENHUMA CONTA ENCONTRADA PARA ESTE CPF'.

      *================================================================
       8500-APLICAR-TARIFAS SECTION.
      *================================================================
       8500-INICIO.
           DISPLAY 'APLICANDO TARIFAS DE MANUTENCAO...'
           MOVE ZEROS TO REG-CONTA-NUM
           START ARQCONTAS KEY >= REG-CONTA-NUM
           PERFORM UNTIL FS-EOF
               READ ARQCONTAS NEXT
               IF NOT FS-EOF
                   MOVE REG-CONTA TO WS-CONTA
                   IF CONTA-ATIVA AND CONTA-CORRENTE
                       SUBTRACT WS-TAXA-MANUT
                               FROM WS-CONTA-SALDO
                       MOVE WS-CONTA TO REG-CONTA
                       REWRITE REG-CONTA
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY 'TARIFAS APLICADAS!'.

      *================================================================
       8800-RELATORIO-CONTAS SECTION.
      *================================================================
       8800-INICIO.
           CALL 'BANKREP' USING LS-RETORNO.

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
