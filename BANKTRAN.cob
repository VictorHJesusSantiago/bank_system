      *================================================================
      * BANKTRAN.COB - Módulo de Processamento de Transações
      * Sistema Bancário COBOL
      * Padrão: Command Pattern + Unit of Work + ACID Compliance
      * Versão: 2.0
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKTRAN.

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

           SELECT ARQTRANS ASSIGN TO 'BANKTRAN.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS REG-TRANS-ID
               FILE STATUS IS FS-TRANS.

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

       01  WS-TRAN-CTRL.
           05  FS-CONTAS            PIC XX.
               88  FS-CONTA-OK      VALUE '00'.
               88  FS-CONTA-NFD     VALUE '23'.
           05  FS-TRANS             PIC XX.
               88  FS-TRANS-OK      VALUE '00'.
               88  FS-TRANS-EOF     VALUE '10'.
           05  WS-OPCAO-TRAN        PIC X(2).
           05  WS-CONTINUAR         PIC X VALUE 'S'.
               88  TRAN-CONTINUAR   VALUE 'S'.
               88  TRAN-PARAR       VALUE 'N'.

       01  WS-CONTA-ORIGEM.
           05  WS-CONTA-ORIGEM-NUM            PIC 9(10).
           05  WS-CONTA-ORIGEM-AGENCIA        PIC 9(4).
           05  WS-CONTA-ORIGEM-DIGITO         PIC 9(1).
           05  WS-CONTA-ORIGEM-TIPO           PIC X(2).
           05  WS-CONTA-ORIGEM-STATUS         PIC X(1).
           05  WS-CONTA-ORIGEM-SALDO          PIC S9(13)V99 COMP-3.
           05  WS-CONTA-ORIGEM-LIMITE         PIC S9(11)V99 COMP-3.
           05  WS-CONTA-ORIGEM-TITULAR        PIC X(60).
           05  WS-CONTA-ORIGEM-CPF            PIC X(11).
           05  WS-CONTA-ORIGEM-EMAIL          PIC X(80).
           05  WS-CONTA-ORIGEM-TELEFONE       PIC X(15).
           05  WS-CONTA-ORIGEM-DT-ABERTURA    PIC 9(8).
           05  WS-CONTA-ORIGEM-DT-ATUALIZACAO PIC 9(8).
           05  WS-CONTA-ORIGEM-SENHA-HASH     PIC X(64).

       01  WS-CONTA-DESTINO.
           05  WS-CONTA-DESTINO-NUM            PIC 9(10).
           05  WS-CONTA-DESTINO-AGENCIA        PIC 9(4).
           05  WS-CONTA-DESTINO-DIGITO         PIC 9(1).
           05  WS-CONTA-DESTINO-TIPO           PIC X(2).
           05  WS-CONTA-DESTINO-STATUS         PIC X(1).
           05  WS-CONTA-DESTINO-SALDO          PIC S9(13)V99 COMP-3.
           05  WS-CONTA-DESTINO-LIMITE         PIC S9(11)V99 COMP-3.
           05  WS-CONTA-DESTINO-TITULAR        PIC X(60).
           05  WS-CONTA-DESTINO-CPF            PIC X(11).
           05  WS-CONTA-DESTINO-EMAIL          PIC X(80).
           05  WS-CONTA-DESTINO-TELEFONE       PIC X(15).
           05  WS-CONTA-DESTINO-DT-ABERTURA    PIC 9(8).
           05  WS-CONTA-DESTINO-DT-ATUALIZACAO PIC 9(8).
           05  WS-CONTA-DESTINO-SENHA-HASH     PIC X(64).

       01  WS-TRAN-DADOS.
           05  WS-VALOR-SOLICITADO  PIC S9(13)V99 COMP-3.
           05  WS-VALOR-COM-TAXA    PIC S9(13)V99 COMP-3.
           05  WS-CONTA-ORIGEM-SALDO-DISPONIVEL PIC S9(13)V99 COMP-3.
           05  WS-VALOR-DISPLAY     PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-SENHA-DIGITADA    PIC X(64).
           05  WS-CONFIRMACAO       PIC X.
           05  WS-TIPO-OPERACAO     PIC X(3) VALUE 'TED'.
           05  WS-TAXA-CORRENTE     PIC S9(5)V99 COMP-3 VALUE ZEROS.

       01  WS-LIMITES.
           05  WS-LIM-SAQUE-DIARIO  PIC S9(9)V99 COMP-3 VALUE 5000,00.
           05  WS-LIM-TRF-DIARIA    PIC S9(9)V99 COMP-3 VALUE 10000,00.
           05  WS-LIM-PIX-DIARIO    PIC S9(9)V99 COMP-3 VALUE 20000,00.
           05  WS-LIM-PIX-NOTURNO   PIC S9(9)V99 COMP-3 VALUE 1000,00.
           05  WS-TOTAL-SAQUE-DIA   PIC S9(9)V99 COMP-3 VALUE ZEROS.
           05  WS-HORA-CORRENTE     PIC 9(4).

       01  WS-TRANS-COUNTER.
           05  WS-PROXIMO-ID        PIC 9(15) VALUE ZEROS.
           05  WS-TRAN-INIT-DT      PIC 9(8).
           05  WS-TRAN-INIT-HR      PIC 9(6).

       01  WS-EXTRATO-CTRL.
           05  WS-DATA-HOJE         PIC 9(8).
           05  WS-DATA-CORTE        PIC 9(8).
           05  WS-DT-INT            PIC 9(7) COMP-5.

       01  WS-TAXAS.
           05  WS-TAXA-TED          PIC S9(5)V99 COMP-3 VALUE 14,90.
           05  WS-TAXA-DOC          PIC S9(5)V99 COMP-3 VALUE 5,80.
           05  WS-TAXA-PIX          PIC S9(5)V99 COMP-3 VALUE 0,00.

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
           OPEN I-O ARQCONTAS ARQTRANS
      *    Inicializa ID de transacao com timestamp para evitar colisao
      *    entre sessoes. Formato: YYYYMMDDHHMMSS * 10 (= 15 digitos)
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-TRAN-INIT-DT
           MOVE FUNCTION CURRENT-DATE(9:6) TO WS-TRAN-INIT-HR
           COMPUTE WS-PROXIMO-ID =
               FUNCTION NUMVAL(WS-TRAN-INIT-DT) * 10000000 +
               FUNCTION NUMVAL(WS-TRAN-INIT-HR) * 10
           PERFORM 1000-MENU-TRANSACOES UNTIL TRAN-PARAR
           CLOSE ARQCONTAS ARQTRANS
           MOVE 0 TO LS-CODIGO
           GOBACK.

      *================================================================
       1000-MENU-TRANSACOES SECTION.
      *================================================================
       1000-INICIO.
           DISPLAY '======================================='
           DISPLAY '      TRANSACOES BANCARIAS'
           DISPLAY '======================================='
           DISPLAY ' 01. Deposito'
           DISPLAY ' 02. Saque'
           DISPLAY ' 03. Transferencia (TED)'
           DISPLAY ' 04. Transferencia (DOC)'
           DISPLAY ' 05. PIX'
           DISPLAY ' 06. Pagamento de Boleto'
           DISPLAY ' 07. Consultar Saldo'
           DISPLAY ' 08. Extrato (30 dias)'
           DISPLAY ' 09. Estornar Transacao'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO-TRAN

           EVALUATE WS-OPCAO-TRAN
               WHEN '01'  PERFORM 2000-DEPOSITO
               WHEN '02'  PERFORM 3000-SAQUE
               WHEN '03'  PERFORM 4000-TRANSFERENCIA-TED
               WHEN '04'  PERFORM 4500-TRANSFERENCIA-DOC
               WHEN '05'  PERFORM 5000-PIX
               WHEN '06'  PERFORM 6000-PAGAMENTO-BOLETO
               WHEN '07'  PERFORM 7000-CONSULTAR-SALDO
               WHEN '08'  PERFORM 8000-EXTRATO
               WHEN '09'  PERFORM 9000-ESTORNAR
               WHEN '00'  MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

      *================================================================
       2000-DEPOSITO SECTION.
      *================================================================
       2000-INICIO.
           DISPLAY '--- DEPOSITO ---'
           DISPLAY 'Numero da Conta: '
           ACCEPT WS-CONTA-ORIGEM-NUM
           PERFORM 2100-BUSCAR-CONTA-ORIGEM
           IF LS-CODIGO = 0
               DISPLAY 'Valor do Deposito: R$ '
               ACCEPT WS-VALOR-SOLICITADO
               IF WS-VALOR-SOLICITADO > ZEROS
                   ADD WS-VALOR-SOLICITADO TO WS-CONTA-ORIGEM-SALDO
                   PERFORM 2200-ATUALIZAR-CONTA-ORIGEM
                   PERFORM 2300-REGISTRAR-TRANSACAO-DEP
                   MOVE WS-VALOR-SOLICITADO TO WS-VALOR-DISPLAY
                   DISPLAY 'DEPOSITO REALIZADO: R$ ' WS-VALOR-DISPLAY
                   MOVE 0 TO LS-CODIGO
               ELSE
                   DISPLAY 'VALOR INVALIDO'
                   MOVE 0003 TO LS-CODIGO
               END-IF
           END-IF.

       2100-BUSCAR-CONTA-ORIGEM.
           MOVE WS-CONTA-ORIGEM-NUM TO REG-CONTA-NUM
           READ ARQCONTAS KEY IS REG-CONTA-NUM
           IF FS-CONTA-NFD
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 0002 TO LS-CODIGO
           ELSE IF FS-CONTA-OK
               MOVE REG-CONTA TO WS-CONTA-ORIGEM
               IF WS-CONTA-ORIGEM-STATUS NOT = 'A'
                   DISPLAY 'CONTA BLOQUEADA OU ENCERRADA'
                   MOVE 0004 TO LS-CODIGO
               ELSE
                   MOVE 0 TO LS-CODIGO
               END-IF
           END-IF.

       2200-ATUALIZAR-CONTA-ORIGEM.
           MOVE WS-CONTA-ORIGEM TO REG-CONTA
           MOVE FUNCTION CURRENT-DATE(1:8)
               TO WS-CONTA-ORIGEM-DT-ATUALIZACAO
           MOVE WS-CONTA-ORIGEM TO REG-CONTA
           REWRITE REG-CONTA
           IF NOT FS-CONTA-OK
               DISPLAY 'ERRO AO ATUALIZAR CONTA: ' FS-CONTAS
               MOVE 9999 TO LS-CODIGO
           END-IF.

       2300-REGISTRAR-TRANSACAO-DEP.
           ADD 1 TO WS-PROXIMO-ID
           MOVE WS-PROXIMO-ID TO WS-TRANS-ID
           MOVE WS-CONTA-ORIGEM-NUM TO WS-TRANS-CONTA-ORG
           MOVE ZEROS TO WS-TRANS-CONTA-DEST
           MOVE 'DEP' TO WS-TRANS-TIPO
           MOVE WS-VALOR-SOLICITADO TO WS-TRANS-VALOR
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-TRANS-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO WS-TRANS-HORA
           MOVE 'Deposito em conta' TO WS-TRANS-DESCRICAO
           MOVE 'E' TO WS-TRANS-STATUS
           MOVE 'AGENCIA' TO WS-TRANS-CANAL
           MOVE WS-TRANSACAO TO REG-TRANS
           WRITE REG-TRANS
           IF NOT FS-TRANS-OK
               DISPLAY 'AVISO: FALHA AO REGISTRAR AUDIT DEP: ' FS-TRANS
           END-IF.

      *================================================================
       3000-SAQUE SECTION.
      *================================================================
       3000-INICIO.
           DISPLAY '--- SAQUE ---'
           DISPLAY 'Numero da Conta: '
           ACCEPT WS-CONTA-ORIGEM-NUM
           PERFORM 2100-BUSCAR-CONTA-ORIGEM
           IF LS-CODIGO = 0
               DISPLAY 'Valor do Saque: R$ '
               ACCEPT WS-VALOR-SOLICITADO
               PERFORM 3100-VALIDAR-SAQUE
               IF LS-CODIGO = 0
                   SUBTRACT WS-VALOR-SOLICITADO
                       FROM WS-CONTA-ORIGEM-SALDO
                   PERFORM 2200-ATUALIZAR-CONTA-ORIGEM
                   PERFORM 3200-REGISTRAR-TRANSACAO-SAQ
                   MOVE WS-VALOR-SOLICITADO TO WS-VALOR-DISPLAY
                   DISPLAY 'SAQUE REALIZADO: R$ ' WS-VALOR-DISPLAY
               END-IF
           END-IF.

       3100-VALIDAR-SAQUE.
      *    Valida saldo disponivel
           COMPUTE WS-CONTA-ORIGEM-SALDO-DISPONIVEL =
               WS-CONTA-ORIGEM-SALDO + WS-CONTA-ORIGEM-LIMITE
           IF WS-VALOR-SOLICITADO > WS-CONTA-ORIGEM-SALDO-DISPONIVEL
               DISPLAY 'SALDO INSUFICIENTE'
               MOVE 0001 TO LS-CODIGO
           ELSE
      *    Valida limite diario
           IF WS-VALOR-SOLICITADO > WS-LIM-SAQUE-DIARIO
               DISPLAY 'EXCEDE LIMITE DIARIO DE SAQUE'
               MOVE 0003 TO LS-CODIGO
           ELSE
           IF WS-VALOR-SOLICITADO <= ZEROS
               DISPLAY 'VALOR INVALIDO'
               MOVE 0003 TO LS-CODIGO
           ELSE
               MOVE 0 TO LS-CODIGO
           END-IF
           END-IF
           END-IF.

       3200-REGISTRAR-TRANSACAO-SAQ.
           ADD 1 TO WS-PROXIMO-ID
           MOVE WS-PROXIMO-ID TO WS-TRANS-ID
           MOVE WS-CONTA-ORIGEM-NUM TO WS-TRANS-CONTA-ORG
           MOVE 'SAQ' TO WS-TRANS-TIPO
           MOVE WS-VALOR-SOLICITADO TO WS-TRANS-VALOR
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-TRANS-DATA
           MOVE FUNCTION CURRENT-DATE(9:6) TO WS-TRANS-HORA
           MOVE 'Saque em conta' TO WS-TRANS-DESCRICAO
           MOVE 'E' TO WS-TRANS-STATUS
           MOVE WS-TRANSACAO TO REG-TRANS
           WRITE REG-TRANS
           IF NOT FS-TRANS-OK
               DISPLAY 'AVISO: FALHA AO REGISTRAR AUDIT SAQ: ' FS-TRANS
           END-IF.

      *================================================================
       4000-TRANSFERENCIA-TED SECTION.
      *================================================================
       4000-INICIO.
           MOVE 'TED' TO WS-TIPO-OPERACAO
           MOVE WS-TAXA-TED TO WS-TAXA-CORRENTE
           DISPLAY '--- TRANSFERENCIA TED ---'
           DISPLAY 'Taxa: R$ ' WS-TAXA-TED
           PERFORM 4100-COLETAR-DADOS-TRF
           PERFORM 4200-VALIDAR-TRANSFERENCIA
           IF LS-CODIGO = 0
               DISPLAY 'Confirmar? (S/N): '
               ACCEPT WS-CONFIRMACAO
               IF WS-CONFIRMACAO = 'S'
                   PERFORM 4300-EXECUTAR-TRANSFERENCIA
                   DISPLAY WS-TIPO-OPERACAO ' REALIZADO COM SUCESSO!'
               ELSE
                   DISPLAY 'OPERACAO CANCELADA'
               END-IF
           END-IF.

       4100-COLETAR-DADOS-TRF.
           DISPLAY 'Conta Origem: '
           ACCEPT WS-CONTA-ORIGEM-NUM
           PERFORM 2100-BUSCAR-CONTA-ORIGEM
           DISPLAY 'Conta Destino: '
           ACCEPT WS-CONTA-DESTINO-NUM
           PERFORM 4150-BUSCAR-CONTA-DESTINO
           DISPLAY 'Valor: R$ '
           ACCEPT WS-VALOR-SOLICITADO.

       4150-BUSCAR-CONTA-DESTINO.
           MOVE WS-CONTA-DESTINO-NUM TO REG-CONTA-NUM
           READ ARQCONTAS KEY IS REG-CONTA-NUM
           IF FS-CONTA-NFD
               DISPLAY 'CONTA DESTINO NAO ENCONTRADA'
               MOVE 0002 TO LS-CODIGO
           ELSE IF FS-CONTA-OK
               MOVE REG-CONTA TO WS-CONTA-DESTINO
               MOVE 0 TO LS-CODIGO
           END-IF.

       4200-VALIDAR-TRANSFERENCIA.
           COMPUTE WS-VALOR-COM-TAXA =
               WS-VALOR-SOLICITADO + WS-TAXA-CORRENTE
           IF WS-VALOR-COM-TAXA >
              (WS-CONTA-ORIGEM-SALDO + WS-CONTA-ORIGEM-LIMITE)
               DISPLAY 'SALDO INSUFICIENTE PARA ' WS-TIPO-OPERACAO
                       ' + TAXA'
               MOVE 0001 TO LS-CODIGO
           ELSE
               MOVE 0 TO LS-CODIGO
           END-IF.

       4300-EXECUTAR-TRANSFERENCIA.
      *    Debitar origem (valor + taxa da operacao corrente)
           SUBTRACT WS-VALOR-SOLICITADO FROM WS-CONTA-ORIGEM-SALDO
           SUBTRACT WS-TAXA-CORRENTE FROM WS-CONTA-ORIGEM-SALDO
           MOVE WS-CONTA-ORIGEM TO REG-CONTA
           REWRITE REG-CONTA
           IF NOT FS-CONTA-OK
               DISPLAY 'ERRO AO DEBITAR CONTA ORIGEM: ' FS-CONTAS
               MOVE 9999 TO LS-CODIGO
           ELSE
      *        Creditar destino
               ADD WS-VALOR-SOLICITADO TO WS-CONTA-DESTINO-SALDO
               MOVE WS-CONTA-DESTINO TO REG-CONTA
               REWRITE REG-CONTA
               IF NOT FS-CONTA-OK
                   DISPLAY 'ERRO AO CREDITAR DESTINO: ' FS-CONTAS
                   MOVE 9999 TO LS-CODIGO
               ELSE
      *            Registrar transacao com tipo correto da operacao
                   ADD 1 TO WS-PROXIMO-ID
                   MOVE WS-TIPO-OPERACAO TO WS-TRANS-TIPO
                   MOVE WS-PROXIMO-ID TO WS-TRANS-ID
                   MOVE WS-CONTA-ORIGEM-NUM TO WS-TRANS-CONTA-ORG
                   MOVE WS-CONTA-DESTINO-NUM TO WS-TRANS-CONTA-DEST
                   MOVE WS-VALOR-SOLICITADO TO WS-TRANS-VALOR
                   MOVE FUNCTION CURRENT-DATE(1:8) TO WS-TRANS-DATA
                   MOVE FUNCTION CURRENT-DATE(9:6) TO WS-TRANS-HORA
                   MOVE 'E' TO WS-TRANS-STATUS
                   MOVE WS-TRANSACAO TO REG-TRANS
                   WRITE REG-TRANS
                   IF NOT FS-TRANS-OK
                       DISPLAY 'AVISO: FALHA AUDIT: ' FS-TRANS
                   ELSE
                       MOVE 0 TO LS-CODIGO
                   END-IF
               END-IF
           END-IF.

       4500-TRANSFERENCIA-DOC SECTION.
       4500-INICIO.
           MOVE 'DOC' TO WS-TIPO-OPERACAO
           MOVE WS-TAXA-DOC TO WS-TAXA-CORRENTE
           DISPLAY '--- TRANSFERENCIA DOC ---'
           DISPLAY 'Taxa: R$ ' WS-TAXA-DOC
           PERFORM 4100-COLETAR-DADOS-TRF
           PERFORM 4200-VALIDAR-TRANSFERENCIA
           IF LS-CODIGO = 0
               DISPLAY 'Confirmar? (S/N): '
               ACCEPT WS-CONFIRMACAO
               IF WS-CONFIRMACAO = 'S'
                   PERFORM 4300-EXECUTAR-TRANSFERENCIA
                   IF LS-CODIGO = 0
                       DISPLAY 'DOC REALIZADO COM SUCESSO!'
                   END-IF
               ELSE
                   DISPLAY 'OPERACAO CANCELADA'
               END-IF
           END-IF.

      *================================================================
       5000-PIX SECTION.
      *================================================================
       5000-INICIO.
           DISPLAY '--- PIX ---'
      *    1. Identificar e validar conta de origem
           DISPLAY 'Conta Origem: '
           ACCEPT WS-CONTA-ORIGEM-NUM
           PERFORM 2100-BUSCAR-CONTA-ORIGEM
           IF LS-CODIGO NOT = 0
               EXIT SECTION
           END-IF
      *    2. Coletar chave e valor
           DISPLAY 'CPF de destino (11 digitos): '
           ACCEPT WS-CONTA-DESTINO-CPF
           DISPLAY 'Valor: R$ '
           ACCEPT WS-VALOR-SOLICITADO
      *    3. Validar valor positivo
           IF WS-VALOR-SOLICITADO <= ZEROS
               DISPLAY 'VALOR INVALIDO'
               MOVE 0003 TO LS-CODIGO
               EXIT SECTION
           END-IF
      *    4. Verificar horario (PIX noturno limitado)
           MOVE FUNCTION CURRENT-DATE(9:4) TO WS-HORA-CORRENTE
           IF WS-HORA-CORRENTE >= 2200 OR WS-HORA-CORRENTE < 0600
               IF WS-VALOR-SOLICITADO > WS-LIM-PIX-NOTURNO
                   DISPLAY 'LIMITE PIX NOTURNO: R$ 1.000,00'
                   MOVE 0003 TO LS-CODIGO
                   EXIT SECTION
               END-IF
           END-IF
      *    5. Validar saldo disponivel (PIX sem taxa)
           COMPUTE WS-CONTA-ORIGEM-SALDO-DISPONIVEL =
               WS-CONTA-ORIGEM-SALDO + WS-CONTA-ORIGEM-LIMITE
           IF WS-VALOR-SOLICITADO > WS-CONTA-ORIGEM-SALDO-DISPONIVEL
               DISPLAY 'SALDO INSUFICIENTE PARA PIX'
               MOVE 0001 TO LS-CODIGO
               EXIT SECTION
           END-IF
      *    6. Buscar conta destino por CPF
           MOVE WS-CONTA-DESTINO-CPF TO REG-CONTA-CPF
           READ ARQCONTAS KEY IS REG-CONTA-CPF
           IF FS-CONTA-NFD
               DISPLAY 'CPF DESTINO NAO ENCONTRADO'
               MOVE 0002 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF NOT FS-CONTA-OK
               DISPLAY 'ERRO DE LEITURA: ' FS-CONTAS
               MOVE 9999 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE REG-CONTA TO WS-CONTA-DESTINO
           IF WS-CONTA-DESTINO-STATUS NOT = 'A'
               DISPLAY 'CONTA DESTINO INATIVA OU BLOQUEADA'
               MOVE 0004 TO LS-CODIGO
               EXIT SECTION
           END-IF
      *    7. Executar PIX: sem taxa, tipo correto antes do WRITE
           MOVE 'PIX' TO WS-TIPO-OPERACAO
           MOVE ZEROS TO WS-TAXA-CORRENTE
           PERFORM 4300-EXECUTAR-TRANSFERENCIA
           IF LS-CODIGO = 0
               DISPLAY 'PIX ENVIADO COM SUCESSO!'
           END-IF.

      *================================================================
       6000-PAGAMENTO-BOLETO SECTION.
      *================================================================
       6000-INICIO.
           DISPLAY '--- PAGAMENTO DE BOLETO ---'
           DISPLAY 'Codigo de Barras: '
           ACCEPT WS-TRANS-DESCRICAO
           DISPLAY 'Conta Debitante: '
           ACCEPT WS-CONTA-ORIGEM-NUM
           PERFORM 2100-BUSCAR-CONTA-ORIGEM
           IF LS-CODIGO = 0
               DISPLAY 'Valor: R$ '
               ACCEPT WS-VALOR-SOLICITADO
               IF WS-VALOR-SOLICITADO <= ZEROS
                   DISPLAY 'VALOR INVALIDO'
                   MOVE 0003 TO LS-CODIGO
               ELSE IF WS-VALOR-SOLICITADO <=
                  (WS-CONTA-ORIGEM-SALDO + WS-CONTA-ORIGEM-LIMITE)
                   SUBTRACT WS-VALOR-SOLICITADO
                       FROM WS-CONTA-ORIGEM-SALDO
                   PERFORM 2200-ATUALIZAR-CONTA-ORIGEM
                   IF LS-CODIGO = 0
      *                Registrar transacao de pagamento no audit
                       ADD 1 TO WS-PROXIMO-ID
                       MOVE WS-PROXIMO-ID    TO WS-TRANS-ID
                       MOVE WS-CONTA-ORIGEM-NUM TO WS-TRANS-CONTA-ORG
                       MOVE ZEROS            TO WS-TRANS-CONTA-DEST
                       MOVE 'PAG'            TO WS-TRANS-TIPO
                       MOVE WS-VALOR-SOLICITADO TO WS-TRANS-VALOR
                       MOVE FUNCTION CURRENT-DATE(1:8) TO WS-TRANS-DATA
                       MOVE FUNCTION CURRENT-DATE(9:6) TO WS-TRANS-HORA
                       MOVE 'E'              TO WS-TRANS-STATUS
                       MOVE 'AGENCIA'        TO WS-TRANS-CANAL
                       MOVE WS-TRANSACAO     TO REG-TRANS
                       WRITE REG-TRANS
                       IF NOT FS-TRANS-OK
                           DISPLAY 'AVISO: FALHA AUDIT BOLETO: '
                                   FS-TRANS
                       END-IF
                       DISPLAY 'BOLETO PAGO COM SUCESSO!'
                       MOVE 0 TO LS-CODIGO
                   END-IF
               ELSE
                   DISPLAY 'SALDO INSUFICIENTE'
                   MOVE 0001 TO LS-CODIGO
               END-IF
           END-IF.

      *================================================================
       7000-CONSULTAR-SALDO SECTION.
      *================================================================
       7000-INICIO.
           DISPLAY 'Numero da Conta: '
           ACCEPT WS-CONTA-ORIGEM-NUM
           PERFORM 2100-BUSCAR-CONTA-ORIGEM
           IF LS-CODIGO = 0
               MOVE WS-CONTA-ORIGEM-SALDO TO WS-VALOR-DISPLAY
               DISPLAY '================================='
               DISPLAY 'SALDO DISPONIVEL'
               DISPLAY 'Conta: ' WS-CONTA-ORIGEM-NUM
               DISPLAY 'Titular: ' WS-CONTA-ORIGEM-TITULAR
               DISPLAY 'Saldo: R$ ' WS-VALOR-DISPLAY
               MOVE WS-CONTA-ORIGEM-LIMITE TO WS-VALOR-DISPLAY
               DISPLAY 'Limite: R$ ' WS-VALOR-DISPLAY
               DISPLAY 'Data: ' WS-TRANS-DATA
               DISPLAY '================================='
           END-IF.

      *================================================================
       8000-EXTRATO SECTION.
      *================================================================
       8000-INICIO.
           DISPLAY 'Numero da Conta: '
           ACCEPT WS-CONTA-ORIGEM-NUM
      *    Calcular data de corte: hoje - 30 dias (usando inteiro de data)
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-DATA-HOJE
           COMPUTE WS-DT-INT =
               FUNCTION INTEGER-OF-DATE(WS-DATA-HOJE) - 30
           COMPUTE WS-DATA-CORTE =
               FUNCTION DATE-OF-INTEGER(WS-DT-INT)
           DISPLAY '--- EXTRATO ULTIMOS 30 DIAS ---'
           DISPLAY 'De: ' WS-DATA-CORTE ' Ate: ' WS-DATA-HOJE
           MOVE ZEROS TO REG-TRANS-ID
           START ARQTRANS KEY >= REG-TRANS-ID
           PERFORM UNTIL FS-TRANS-EOF
               READ ARQTRANS NEXT
               IF NOT FS-TRANS-EOF
                   MOVE REG-TRANS TO WS-TRANSACAO
                   IF (WS-TRANS-CONTA-ORG = WS-CONTA-ORIGEM-NUM OR
                       WS-TRANS-CONTA-DEST = WS-CONTA-ORIGEM-NUM)
                      AND WS-TRANS-DATA >= WS-DATA-CORTE
                       MOVE WS-TRANS-VALOR TO WS-VALOR-DISPLAY
                       DISPLAY WS-TRANS-DATA SPACE
                               WS-TRANS-TIPO SPACE
                               WS-TRANS-DESCRICAO(1:25) SPACE
                               WS-VALOR-DISPLAY SPACE
                               WS-TRANS-STATUS
                   END-IF
               END-IF
           END-PERFORM.

      *================================================================
       9000-ESTORNAR SECTION.
      *================================================================
       9000-INICIO.
           DISPLAY 'ID da Transacao para Estorno: '
           ACCEPT WS-TRANS-ID
           MOVE WS-TRANS-ID TO REG-TRANS-ID
           READ ARQTRANS KEY IS REG-TRANS-ID
           IF FS-TRANS-OK
               MOVE REG-TRANS TO WS-TRANSACAO
               IF WS-TRANS-STATUS = 'E'
                   MOVE 'X' TO WS-TRANS-STATUS
                   MOVE WS-TRANSACAO TO REG-TRANS
                   REWRITE REG-TRANS
      *            Estornar valores nas contas
                   PERFORM 9100-REVERTER-VALORES
                   DISPLAY 'TRANSACAO ESTORNADA!'
                   MOVE 0 TO LS-CODIGO
               ELSE
                   DISPLAY 'TRANSACAO NAO PODE SER ESTORNADA'
                   MOVE 0003 TO LS-CODIGO
               END-IF
           ELSE
               DISPLAY 'TRANSACAO NAO ENCONTRADA'
               MOVE 0002 TO LS-CODIGO
           END-IF.

       9100-REVERTER-VALORES.
           EVALUATE WS-TRANS-TIPO
               WHEN 'DEP'
      *            Estorno de deposito: subtrair o valor creditado
                   MOVE WS-TRANS-CONTA-ORG TO REG-CONTA-NUM
                   READ ARQCONTAS KEY IS REG-CONTA-NUM
                   IF FS-CONTA-OK
                       MOVE REG-CONTA TO WS-CONTA
                       SUBTRACT WS-TRANS-VALOR FROM WS-CONTA-SALDO
                       MOVE WS-CONTA TO REG-CONTA
                       REWRITE REG-CONTA
                       IF NOT FS-CONTA-OK
                           DISPLAY 'ERRO ESTORNO DEP: ' FS-CONTAS
                       END-IF
                   ELSE
                       DISPLAY 'CONTA NAO LOCALIZADA PARA ESTORNO'
                   END-IF
               WHEN 'SAQ'
      *            Estorno de saque: devolver o valor debitado
                   MOVE WS-TRANS-CONTA-ORG TO REG-CONTA-NUM
                   READ ARQCONTAS KEY IS REG-CONTA-NUM
                   IF FS-CONTA-OK
                       MOVE REG-CONTA TO WS-CONTA
                       ADD WS-TRANS-VALOR TO WS-CONTA-SALDO
                       MOVE WS-CONTA TO REG-CONTA
                       REWRITE REG-CONTA
                       IF NOT FS-CONTA-OK
                           DISPLAY 'ERRO ESTORNO SAQ: ' FS-CONTAS
                       END-IF
                   ELSE
                       DISPLAY 'CONTA NAO LOCALIZADA PARA ESTORNO'
                   END-IF
               WHEN OTHER
                   DISPLAY 'ESTORNO MANUAL NECESSARIO'
           END-EVALUATE.

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
