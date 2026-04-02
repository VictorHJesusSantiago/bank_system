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

       01  WS-LIMITES.
           05  WS-LIM-SAQUE-DIARIO  PIC S9(9)V99 COMP-3 VALUE 5000,00.
           05  WS-LIM-TRF-DIARIA    PIC S9(9)V99 COMP-3 VALUE 10000,00.
           05  WS-LIM-PIX-DIARIO    PIC S9(9)V99 COMP-3 VALUE 20000,00.
           05  WS-LIM-PIX-NOTURNO   PIC S9(9)V99 COMP-3 VALUE 1000,00.
           05  WS-TOTAL-SAQUE-DIA   PIC S9(9)V99 COMP-3 VALUE ZEROS.
           05  WS-HORA-CORRENTE     PIC 9(4).

       01  WS-TRANS-COUNTER.
           05  WS-PROXIMO-ID        PIC 9(15) VALUE ZEROS.

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
           WRITE REG-TRANS.

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
           WRITE REG-TRANS.

      *================================================================
       4000-TRANSFERENCIA-TED SECTION.
      *================================================================
       4000-INICIO.
           DISPLAY '--- TRANSFERENCIA TED ---'
           DISPLAY 'Taxa: R$ ' WS-TAXA-TED
           PERFORM 4100-COLETAR-DADOS-TRF
           PERFORM 4200-VALIDAR-TRANSFERENCIA
           IF LS-CODIGO = 0
               DISPLAY 'Confirmar? (S/N): '
               ACCEPT WS-CONFIRMACAO
               IF WS-CONFIRMACAO = 'S'
                   PERFORM 4300-EXECUTAR-TRANSFERENCIA
                   DISPLAY 'TED REALIZADO COM SUCESSO!'
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
               WS-VALOR-SOLICITADO + WS-TAXA-TED
           IF WS-VALOR-COM-TAXA >
              (WS-CONTA-ORIGEM-SALDO + WS-CONTA-ORIGEM-LIMITE)
               DISPLAY 'SALDO INSUFICIENTE PARA TED + TAXA'
               MOVE 0001 TO LS-CODIGO
           ELSE
               MOVE 0 TO LS-CODIGO
           END-IF.

       4300-EXECUTAR-TRANSFERENCIA.
      *    Debitar origem
           SUBTRACT WS-VALOR-SOLICITADO FROM WS-CONTA-ORIGEM-SALDO
           SUBTRACT WS-TAXA-TED FROM WS-CONTA-ORIGEM-SALDO
           MOVE WS-CONTA-ORIGEM TO REG-CONTA
           REWRITE REG-CONTA
      *    Creditar destino
           ADD WS-VALOR-SOLICITADO TO WS-CONTA-DESTINO-SALDO
           MOVE WS-CONTA-DESTINO TO REG-CONTA
           REWRITE REG-CONTA
      *    Registrar transacao
           ADD 1 TO WS-PROXIMO-ID
           MOVE 'TED' TO WS-TRANS-TIPO
           MOVE WS-PROXIMO-ID TO WS-TRANS-ID
           MOVE WS-CONTA-ORIGEM-NUM TO WS-TRANS-CONTA-ORG
           MOVE WS-CONTA-DESTINO-NUM TO WS-TRANS-CONTA-DEST
           MOVE WS-VALOR-SOLICITADO TO WS-TRANS-VALOR
           MOVE 'E' TO WS-TRANS-STATUS
           MOVE WS-TRANSACAO TO REG-TRANS
           WRITE REG-TRANS.

       4500-TRANSFERENCIA-DOC.
           MOVE WS-TAXA-DOC TO WS-TAXA-TED
           PERFORM 4000-TRANSFERENCIA-TED.

      *================================================================
       5000-PIX SECTION.
      *================================================================
       5000-INICIO.
           DISPLAY '--- PIX ---'
           DISPLAY 'Chave PIX (CPF/Email/Tel/Aleatoria): '
           ACCEPT WS-CONTA-DESTINO-CPF
           DISPLAY 'Valor: R$ '
           ACCEPT WS-VALOR-SOLICITADO
      *    Verificar horario (PIX noturno limitado)
           MOVE FUNCTION CURRENT-DATE(9:4) TO WS-HORA-CORRENTE
           IF WS-HORA-CORRENTE >= 2200 OR WS-HORA-CORRENTE < 0600
               IF WS-VALOR-SOLICITADO > WS-LIM-PIX-NOTURNO
                   DISPLAY 'LIMITE PIX NOTURNO: R$ 1.000,00'
                   MOVE 0003 TO LS-CODIGO
                   EXIT SECTION
               END-IF
           END-IF
      *    Buscar por chave
         MOVE WS-CONTA-DESTINO-CPF TO REG-CONTA-CPF
         READ ARQCONTAS KEY IS REG-CONTA-CPF
           IF FS-CONTA-OK
               MOVE REG-CONTA TO WS-CONTA-DESTINO
               PERFORM 4300-EXECUTAR-TRANSFERENCIA
               MOVE 'PIX' TO WS-TRANS-TIPO
               DISPLAY 'PIX ENVIADO COM SUCESSO!'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'CHAVE PIX NAO ENCONTRADA'
               MOVE 0002 TO LS-CODIGO
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
               IF WS-VALOR-SOLICITADO <=
                  (WS-CONTA-ORIGEM-SALDO + WS-CONTA-ORIGEM-LIMITE)
                   SUBTRACT WS-VALOR-SOLICITADO
                       FROM WS-CONTA-ORIGEM-SALDO
                   PERFORM 2200-ATUALIZAR-CONTA-ORIGEM
                   DISPLAY 'BOLETO PAGO COM SUCESSO!'
                   MOVE 0 TO LS-CODIGO
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
           DISPLAY '--- EXTRATO ULTIMOS 30 DIAS ---'
           MOVE ZEROS TO REG-TRANS-ID
           START ARQTRANS KEY >= REG-TRANS-ID
           PERFORM UNTIL FS-TRANS-EOF
               READ ARQTRANS NEXT
               IF NOT FS-TRANS-EOF
                   MOVE REG-TRANS TO WS-TRANSACAO
                   IF WS-TRANS-CONTA-ORG = WS-CONTA-ORIGEM-NUM OR
                      WS-TRANS-CONTA-DEST = WS-CONTA-ORIGEM-NUM
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
           READ ARQTRANS KEY IS WS-TRANS-ID
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
                   READ ARQCONTAS KEY IS WS-TRANS-CONTA-ORG
                   MOVE REG-CONTA TO WS-CONTA
                   SUBTRACT WS-TRANS-VALOR FROM WS-CONTA-SALDO
                   MOVE WS-CONTA TO REG-CONTA
                   REWRITE REG-CONTA
               WHEN 'SAQ'
                   READ ARQCONTAS KEY IS WS-TRANS-CONTA-ORG
                   MOVE REG-CONTA TO WS-CONTA
                   ADD WS-TRANS-VALOR TO WS-CONTA-SALDO
                   MOVE WS-CONTA TO REG-CONTA
                   REWRITE REG-CONTA
               WHEN OTHER
                   DISPLAY 'ESTORNO MANUAL NECESSARIO'
           END-EVALUATE.

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
