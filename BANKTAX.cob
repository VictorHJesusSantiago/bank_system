       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKTAX.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQTRANS ASSIGN TO 'BANKTRAN.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS TX-TRANS-ID
               FILE STATUS IS FS-TRANS.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS TX-CONTA-NUM
               FILE STATUS IS FS-CONTAS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQTRANS.
       01  REG-TRANS.
           05  TX-TRANS-ID           PIC 9(15).
           05  TX-TRANS-CONTA-ORG    PIC 9(10).
           05  TX-TRANS-CONTA-DEST   PIC 9(10).
           05  TX-TRANS-TIPO         PIC X(3).
           05  TX-TRANS-VALOR        PIC S9(13)V99 COMP-3.
           05  TX-TRANS-DATA         PIC 9(8).
           05  TX-TRANS-HORA         PIC 9(6).
           05  TX-TRANS-DESCR        PIC X(100).
           05  TX-TRANS-STATUS       PIC X(1).
           05  TX-TRANS-NSU          PIC 9(12).
           05  TX-TRANS-CANAL        PIC X(10).

       FD  ARQCONTAS.
       01  REG-CONTA.
           05  TX-CONTA-NUM          PIC 9(10).
           05  TX-CONTA-AGENCIA      PIC 9(4).
           05  TX-CONTA-DIGITO       PIC 9(1).
           05  TX-CONTA-TIPO         PIC X(2).
           05  TX-CONTA-STATUS       PIC X(1).
           05  TX-CONTA-SALDO        PIC S9(13)V99 COMP-3.
           05  TX-CONTA-LIMITE       PIC S9(11)V99 COMP-3.
           05  TX-CONTA-TITULAR      PIC X(60).
           05  TX-CONTA-CPF          PIC X(11).
           05  FILLER                PIC X(168).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-TAX-CTRL.
           05  FS-TRANS              PIC XX.
               88  FS-TR-OK          VALUE '00'.
               88  FS-TR-EOF         VALUE '10'.
           05  FS-CONTAS             PIC XX.
               88  FS-CT-OK          VALUE '00'.
               88  FS-CT-NFD         VALUE '23'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  TAX-PARAR         VALUE 'N'.

       01  WS-TAX-CALC.
           05  WS-TAX-CONTA          PIC 9(10).
           05  WS-TAX-ANO            PIC 9(4).
           05  WS-TAX-ANO-X          PIC X(4).
           05  WS-TAX-REC-REN        PIC S9(13)V99 COMP-3.
           05  WS-TAX-REC-TAR        PIC S9(13)V99 COMP-3.
           05  WS-TAX-REC-JUR        PIC S9(13)V99 COMP-3.
           05  WS-TAX-IRRF           PIC S9(11)V99 COMP-3.
           05  WS-TAX-SALDO_31_12    PIC S9(13)V99 COMP-3.
           05  WS-TAX-CTR            PIC 9(8) COMP-3.
           05  WS-TAX-DATA-STR       PIC X(8).
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN INPUT ARQTRANS ARQCONTAS
           PERFORM 1000-MENU UNTIL TAX-PARAR
           CLOSE ARQTRANS ARQCONTAS
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU SECTION.
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '  INFORME DE RENDIMENTOS - IMPOSTO DE RENDA'
           DISPLAY '========================================'
           DISPLAY ' 01. Gerar Informe de Rendimentos'
           DISPLAY ' 02. Rendimentos por Categoria'
           DISPLAY ' 03. IRRF - Imposto Retido na Fonte'
           DISPLAY ' 04. Saldo em 31/12'
           DISPLAY ' 05. Movimentacoes para Declaracao'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-INFORME-COMPLETO
               WHEN '02' PERFORM 3000-POR-CATEGORIA
               WHEN '03' PERFORM 4000-IRRF
               WHEN '04' PERFORM 5000-SALDO-3112
               WHEN '05' PERFORM 6000-MOVIMENTACOES
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-INFORME-COMPLETO SECTION.
       2000-INICIO.
           DISPLAY 'Numero da conta: '
           ACCEPT WS-TAX-CONTA
           DISPLAY 'Ano-base (ex: 2025): '
           ACCEPT WS-TAX-ANO
           PERFORM 9700-VARRER-TRANSACOES
           MOVE WS-TAX-CONTA TO TX-CONTA-NUM
           READ ARQCONTAS KEY IS TX-CONTA-NUM
           DISPLAY '========================================'
           DISPLAY ' INFORME DE RENDIMENTOS'
           DISPLAY ' Ano-Calendario: ' WS-TAX-ANO
           DISPLAY ' Instituicao: BANCO COBOL S.A.'
           DISPLAY ' CNPJ: 00.000.000/0001-00'
           IF FS-CT-OK
               DISPLAY ' Titular: ' TX-CONTA-TITULAR(1:40)
               DISPLAY ' CPF: ' TX-CONTA-CPF
           END-IF
           DISPLAY ' Conta: ' WS-TAX-CONTA
           DISPLAY '========================================'
           MOVE WS-TAX-REC-REN TO WS-DIS
           DISPLAY ' Rendimentos de Renda Fixa: R$ ' WS-DIS
           MOVE WS-TAX-REC-JUR TO WS-DIS
           DISPLAY ' Juros Recebidos:           R$ ' WS-DIS
           MOVE WS-TAX-REC-TAR TO WS-DIS
           DISPLAY ' Tarifas Pagas (deducoes):  R$ ' WS-DIS
           MOVE WS-TAX-IRRF TO WS-DIS
           DISPLAY ' IRRF (15%):              - R$ ' WS-DIS
           DISPLAY '========================================'
           DISPLAY ' * Declarar na ficha Rendimentos Isentos'
           DISPLAY '   e Nao Tributaveis, codigo 12'
           MOVE 0 TO LS-CODIGO.

       3000-POR-CATEGORIA SECTION.
       3000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-TAX-CONTA
           DISPLAY 'Ano: '
           ACCEPT WS-TAX-ANO
           PERFORM 9700-VARRER-TRANSACOES
           DISPLAY '========================================'
           DISPLAY ' RENDIMENTOS POR CATEGORIA - ' WS-TAX-ANO
           DISPLAY '========================================'
           MOVE WS-TAX-REC-REN TO WS-DIS
           DISPLAY ' CDB/LCI/LCA/Fundos:  R$ ' WS-DIS
           MOVE WS-TAX-REC-JUR TO WS-DIS
           DISPLAY ' Juros (emprestimos): R$ ' WS-DIS
           MOVE WS-TAX-REC-TAR TO WS-DIS
           DISPLAY ' Tarifas bancarias:   R$ ' WS-DIS
           DISPLAY ' Operacoes: ' WS-TAX-CTR
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       4000-IRRF SECTION.
       4000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-TAX-CONTA
           DISPLAY 'Ano: '
           ACCEPT WS-TAX-ANO
           PERFORM 9700-VARRER-TRANSACOES
           COMPUTE WS-TAX-IRRF =
               (WS-TAX-REC-REN + WS-TAX-REC-JUR) * 0,15
           MOVE WS-TAX-IRRF TO WS-DIS
           DISPLAY '========================================'
           DISPLAY ' IRRF - ANO ' WS-TAX-ANO
           DISPLAY '========================================'
           DISPLAY ' Base de calculo:'
           MOVE WS-TAX-REC-REN TO WS-DIS
           DISPLAY '   Rendimentos: R$ ' WS-DIS
           COMPUTE WS-TAX-IRRF =
               (WS-TAX-REC-REN + WS-TAX-REC-JUR) * 0,15
           MOVE WS-TAX-IRRF TO WS-DIS
           DISPLAY ' IRRF calculado (15%): R$ ' WS-DIS
           DISPLAY ' Codigo DARF: 3208'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       5000-SALDO-3112 SECTION.
       5000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-TAX-CONTA
           DISPLAY 'Ano: '
           ACCEPT WS-TAX-ANO
           MOVE WS-TAX-CONTA TO TX-CONTA-NUM
           READ ARQCONTAS KEY IS TX-CONTA-NUM
           IF FS-CT-NFD
               DISPLAY 'CONTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE TX-CONTA-SALDO TO WS-DIS
           DISPLAY '========================================'
           DISPLAY ' SALDO EM 31/12/' WS-TAX-ANO
           DISPLAY '========================================'
           DISPLAY ' Conta: ' WS-TAX-CONTA
           DISPLAY ' Saldo: R$ ' WS-DIS
           DISPLAY ' Declarar na ficha Bens e Direitos'
           DISPLAY ' Codigo 61 - Depositos bancarios'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       6000-MOVIMENTACOES SECTION.
       6000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-TAX-CONTA
           DISPLAY 'Ano: '
           ACCEPT WS-TAX-ANO
           MOVE WS-TAX-ANO TO WS-TAX-ANO-X
           MOVE ZEROS TO WS-TAX-CTR
           DISPLAY '========================================'
           DISPLAY ' MOVIMENTACOES RELEVANTES - ' WS-TAX-ANO
           DISPLAY ' (transacoes >= R$ 5.000,00)'
           DISPLAY ' Data     Tipo  Valor'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO TX-TRANS-ID
           START ARQTRANS KEY >= TX-TRANS-ID
           PERFORM UNTIL FS-TR-EOF
               READ ARQTRANS NEXT
               IF FS-TR-OK
                   MOVE TX-TRANS-DATA TO WS-TAX-DATA-STR
                   IF WS-TAX-DATA-STR(1:4) = WS-TAX-ANO-X
                   AND (TX-TRANS-CONTA-ORG = WS-TAX-CONTA
                    OR TX-TRANS-CONTA-DEST = WS-TAX-CONTA)
                   AND TX-TRANS-VALOR >= 5000,00
                       MOVE TX-TRANS-VALOR TO WS-DIS
                       DISPLAY TX-TRANS-DATA ' '
                               TX-TRANS-TIPO '  R$ ' WS-DIS
                       ADD 1 TO WS-TAX-CTR
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '----------------------------------------'
           DISPLAY ' Total de operacoes: ' WS-TAX-CTR
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       9700-VARRER-TRANSACOES.
           MOVE ZEROS TO WS-TAX-REC-REN WS-TAX-REC-TAR
                         WS-TAX-REC-JUR WS-TAX-CTR
           MOVE WS-TAX-ANO TO WS-TAX-ANO-X
           MOVE ZEROS TO TX-TRANS-ID
           START ARQTRANS KEY >= TX-TRANS-ID
           PERFORM UNTIL FS-TR-EOF
               READ ARQTRANS NEXT
               IF FS-TR-OK
                   MOVE TX-TRANS-DATA TO WS-TAX-DATA-STR
                   IF WS-TAX-DATA-STR(1:4) = WS-TAX-ANO-X
                   AND (TX-TRANS-CONTA-ORG = WS-TAX-CONTA
                    OR TX-TRANS-CONTA-DEST = WS-TAX-CONTA)
                       ADD 1 TO WS-TAX-CTR
                       EVALUATE TX-TRANS-TIPO
                           WHEN 'REN'
                               ADD TX-TRANS-VALOR TO WS-TAX-REC-REN
                           WHEN 'TAR'
                               ADD TX-TRANS-VALOR TO WS-TAX-REC-TAR
                           WHEN 'JUR'
                               ADD TX-TRANS-VALOR TO WS-TAX-REC-JUR
                       END-EVALUATE
                   END-IF
               END-IF
           END-PERFORM
           COMPUTE WS-TAX-IRRF =
               (WS-TAX-REC-REN + WS-TAX-REC-JUR) * 0,15.

       9999-FIM.
           EXIT PROGRAM.
