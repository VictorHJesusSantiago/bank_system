      *================================================================
      * BANKCASHBACK.COB - Cashback e Programa de Fidelidade
      * Sistema Bancario COBOL
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKCASHBACK.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCASHB ASSIGN TO 'BANKCASHBACK.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS CASHB-ID
               FILE STATUS IS FS-CASHB.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCASHB.
       01  REG-CASHB.
           05  CASHB-ID              PIC 9(15).
           05  CASHB-CONTA           PIC 9(10).
           05  CASHB-CATEGORIA       PIC X(15).
           05  CASHB-VALOR-COMPRA    PIC S9(11)V99 COMP-3.
           05  CASHB-PERCENTUAL      PIC 9(2)V99 COMP-3.
           05  CASHB-VALOR-CASHBACK  PIC S9(9)V99 COMP-3.
           05  CASHB-PONTOS          PIC 9(9).
           05  CASHB-DATA            PIC 9(8).
           05  CASHB-STATUS          PIC X(1).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-CASHB-CTRL.
           05  FS-CASHB              PIC XX.
               88  FS-CASHB-OK       VALUE '00'.
               88  FS-CASHB-EOF      VALUE '10'.
               88  FS-CASHB-NFD      VALUE '23'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CASHB-PARAR       VALUE 'N'.
           05  WS-CASHB-SEQ          PIC 9(15) VALUE ZEROS.

       01  WS-CASHB-CALC.
           05  WS-CASHB-CONTA-NUM    PIC 9(10).
           05  WS-CASHB-ID-SEL       PIC 9(15).
           05  WS-CASHB-CTR          PIC 9(6) COMP-3.
           05  WS-CASHB-TOT-CASHBACK PIC S9(11)V99 COMP-3.
           05  WS-CASHB-TOT-PONTOS   PIC 9(11).
           05  WS-CASHB-TOT-CRED     PIC S9(11)V99 COMP-3.
           05  WS-CASHB-NIVEL        PIC X(10).
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQCASHB
           IF NOT FS-CASHB-OK
               OPEN OUTPUT ARQCASHB
               CLOSE ARQCASHB
               OPEN I-O ARQCASHB
           END-IF
           PERFORM 9900-SEQ
           PERFORM 1000-MENU UNTIL CASHB-PARAR
           CLOSE ARQCASHB
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-SEQ.
           MOVE 999999999999999 TO CASHB-ID
           START ARQCASHB KEY <= CASHB-ID
           READ ARQCASHB PREVIOUS
           IF FS-CASHB-OK
               MOVE CASHB-ID TO WS-CASHB-SEQ
           ELSE
               MOVE ZEROS TO WS-CASHB-SEQ
           END-IF.

      *================================================================
       1000-MENU SECTION.
      *================================================================
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '   CASHBACK E PROGRAMA DE FIDELIDADE'
           DISPLAY '========================================'
           DISPLAY ' 01. Registrar Compra com Cashback'
           DISPLAY ' 02. Consultar Saldo de Cashback/Pontos'
           DISPLAY ' 03. Resgatar Cashback (creditar em conta)'
           DISPLAY ' 04. Trocar Pontos por Beneficios'
           DISPLAY ' 05. Extrato de Cashback'
           DISPLAY ' 06. Meu Nivel de Fidelidade'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-REGISTRAR
               WHEN '02' PERFORM 3000-SALDO
               WHEN '03' PERFORM 4000-RESGATAR
               WHEN '04' PERFORM 5000-TROCAR-PONTOS
               WHEN '05' PERFORM 6000-EXTRATO
               WHEN '06' PERFORM 7000-NIVEL
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

      *================================================================
       2000-REGISTRAR SECTION.
      *================================================================
       2000-INICIO.
           DISPLAY '--- REGISTRAR COMPRA COM CASHBACK ---'
           DISPLAY 'Conta: '
           ACCEPT WS-CASHB-CONTA-NUM
           DISPLAY 'Categoria (SUPERMERCADO/COMBUSTIVEL/FARMACIA/'
           DISPLAY '           RESTAURANTE/OUTROS): '
           ACCEPT CASHB-CATEGORIA
           DISPLAY 'Valor da compra (R$): '
           ACCEPT CASHB-VALOR-COMPRA
           EVALUATE CASHB-CATEGORIA
               WHEN 'SUPERMERCADO' MOVE 2,00 TO CASHB-PERCENTUAL
               WHEN 'COMBUSTIVEL'  MOVE 3,00 TO CASHB-PERCENTUAL
               WHEN 'FARMACIA'     MOVE 4,00 TO CASHB-PERCENTUAL
               WHEN 'RESTAURANTE'  MOVE 1,50 TO CASHB-PERCENTUAL
               WHEN OTHER          MOVE 0,50 TO CASHB-PERCENTUAL
           END-EVALUATE
           COMPUTE CASHB-VALOR-CASHBACK ROUNDED =
               CASHB-VALOR-COMPRA * CASHB-PERCENTUAL / 100
           COMPUTE CASHB-PONTOS =
               CASHB-VALOR-COMPRA * 10
           ADD 1 TO WS-CASHB-SEQ
           MOVE WS-CASHB-SEQ TO CASHB-ID
           MOVE WS-CASHB-CONTA-NUM TO CASHB-CONTA
           MOVE FUNCTION CURRENT-DATE(1:8) TO CASHB-DATA
           MOVE 'P' TO CASHB-STATUS
           WRITE REG-CASHB
           IF FS-CASHB-OK
               MOVE CASHB-VALOR-CASHBACK TO WS-DIS
               DISPLAY 'COMPRA REGISTRADA!'
               DISPLAY ' Cashback gerado (' CASHB-PERCENTUAL
                       '%): R$ ' WS-DIS
               DISPLAY ' Pontos gerados: ' CASHB-PONTOS
               DISPLAY ' Credito em ate 7 dias uteis'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO: ' FS-CASHB
               MOVE 9999 TO LS-CODIGO
           END-IF.

      *================================================================
       3000-SALDO SECTION.
      *================================================================
       3000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-CASHB-CONTA-NUM
           PERFORM 9700-TOTALIZAR
           DISPLAY '========================================'
           DISPLAY ' SALDO DE CASHBACK / PONTOS - CONTA '
                   WS-CASHB-CONTA-NUM
           MOVE WS-CASHB-TOT-CASHBACK TO WS-DIS
           DISPLAY ' Cashback pendente:  R$ ' WS-DIS
           MOVE WS-CASHB-TOT-CRED TO WS-DIS
           DISPLAY ' Cashback resgatado: R$ ' WS-DIS
           DISPLAY ' Pontos acumulados:  ' WS-CASHB-TOT-PONTOS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       4000-RESGATAR SECTION.
      *================================================================
       4000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-CASHB-CONTA-NUM
           PERFORM 9700-TOTALIZAR
           MOVE WS-CASHB-TOT-CASHBACK TO WS-DIS
           DISPLAY 'Cashback pendente disponivel: R$ ' WS-DIS
           IF WS-CASHB-TOT-CASHBACK = ZEROS
               DISPLAY 'NAO HA CASHBACK DISPONIVEL PARA RESGATE'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Confirmar resgate (credito em conta)? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO NOT = 'S'
               DISPLAY 'OPERACAO ABORTADA'
               EXIT SECTION
           END-IF
           MOVE ZEROS TO CASHB-ID
           START ARQCASHB KEY >= CASHB-ID
           PERFORM UNTIL FS-CASHB-EOF
               READ ARQCASHB NEXT
               IF FS-CASHB-OK
                   IF CASHB-CONTA = WS-CASHB-CONTA-NUM
                   AND CASHB-STATUS = 'P'
                       MOVE 'C' TO CASHB-STATUS
                       REWRITE REG-CASHB
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY 'CASHBACK CREDITADO EM CONTA COM SUCESSO!'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       5000-TROCAR-PONTOS SECTION.
      *================================================================
       5000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-CASHB-CONTA-NUM
           PERFORM 9700-TOTALIZAR
           DISPLAY 'Pontos disponiveis: ' WS-CASHB-TOT-PONTOS
           DISPLAY '========================================'
           DISPLAY ' CATALOGO DE BENEFICIOS'
           DISPLAY '----------------------------------------'
           DISPLAY ' 5.000  pts  -> R$ 25 em vale-compras'
           DISPLAY ' 10.000 pts  -> Mensalidade gratis'
           DISPLAY ' 20.000 pts  -> Milhas aereas (2.000 milhas)'
           DISPLAY ' 50.000 pts  -> Cartao adicional sem anuidade 1 ano'
           DISPLAY '========================================'
           DISPLAY 'Quantos pontos deseja trocar? '
           ACCEPT WS-CASHB-TOT-PONTOS
           IF WS-CASHB-TOT-PONTOS > ZEROS
               DISPLAY 'RESGATE DE BENEFICIO SOLICITADO COM SUCESSO!'
               DISPLAY ' O beneficio sera processado em ate 24h'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'QUANTIDADE INVALIDA'
               MOVE 4 TO LS-CODIGO
           END-IF.

      *================================================================
       6000-EXTRATO SECTION.
      *================================================================
       6000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-CASHB-CONTA-NUM
           DISPLAY '========================================'
           DISPLAY ' EXTRATO DE CASHBACK - CONTA '
                   WS-CASHB-CONTA-NUM
           DISPLAY ' Data      Categoria      Compra    Cashback  St'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO CASHB-ID
           START ARQCASHB KEY >= CASHB-ID
           PERFORM UNTIL FS-CASHB-EOF
               READ ARQCASHB NEXT
               IF FS-CASHB-OK
                   IF CASHB-CONTA = WS-CASHB-CONTA-NUM
                       MOVE CASHB-VALOR-CASHBACK TO WS-DIS
                       DISPLAY CASHB-DATA ' '
                               CASHB-CATEGORIA(1:13) ' '
                               'R$ ' WS-DIS ' ' CASHB-STATUS
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       7000-NIVEL SECTION.
      *================================================================
       7000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-CASHB-CONTA-NUM
           PERFORM 9700-TOTALIZAR
           EVALUATE TRUE
               WHEN WS-CASHB-TOT-PONTOS >= 100000
                   MOVE 'PLATINA' TO WS-CASHB-NIVEL
               WHEN WS-CASHB-TOT-PONTOS >= 50000
                   MOVE 'OURO' TO WS-CASHB-NIVEL
               WHEN WS-CASHB-TOT-PONTOS >= 20000
                   MOVE 'PRATA' TO WS-CASHB-NIVEL
               WHEN OTHER
                   MOVE 'BRONZE' TO WS-CASHB-NIVEL
           END-EVALUATE
           DISPLAY '========================================'
           DISPLAY ' SEU NIVEL DE FIDELIDADE: ' WS-CASHB-NIVEL
           DISPLAY ' Pontos acumulados: ' WS-CASHB-TOT-PONTOS
           DISPLAY ' Quanto maior o nivel, maiores os percentuais'
           DISPLAY ' de cashback e beneficios exclusivos.'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       9700-TOTALIZAR.
      *================================================================
           MOVE ZEROS TO WS-CASHB-TOT-CASHBACK WS-CASHB-TOT-PONTOS
                         WS-CASHB-TOT-CRED WS-CASHB-CTR
           MOVE ZEROS TO CASHB-ID
           START ARQCASHB KEY >= CASHB-ID
           PERFORM UNTIL FS-CASHB-EOF
               READ ARQCASHB NEXT
               IF FS-CASHB-OK
                   IF CASHB-CONTA = WS-CASHB-CONTA-NUM
                       ADD CASHB-PONTOS TO WS-CASHB-TOT-PONTOS
                       EVALUATE CASHB-STATUS
                           WHEN 'P'
                               ADD CASHB-VALOR-CASHBACK
                                   TO WS-CASHB-TOT-CASHBACK
                           WHEN 'C'
                               ADD CASHB-VALOR-CASHBACK
                                   TO WS-CASHB-TOT-CRED
                       END-EVALUATE
                   END-IF
               END-IF
           END-PERFORM.

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
