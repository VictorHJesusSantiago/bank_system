      *================================================================
      * BANKCONS.COB - Modulo de Consorcio
      * Sistema Bancario COBOL
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKCONS.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONS ASSIGN TO 'BANKCONS.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS CONS-ID
               FILE STATUS IS FS-CONS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONS.
       01  REG-CONS.
           05  CONS-ID               PIC 9(12).
           05  CONS-CONTA            PIC 9(10).
           05  CONS-TIPO             PIC X(5).
           05  CONS-PARTICIPANTE     PIC X(60).
           05  CONS-CPF              PIC X(11).
           05  CONS-VALOR-BEM        PIC S9(13)V99 COMP-3.
           05  CONS-PARCELA          PIC S9(9)V99 COMP-3.
           05  CONS-PRAZO-MESES      PIC 9(4).
           05  CONS-PARCELAS-PAGAS   PIC 9(4).
           05  CONS-TX-ADM           PIC 9(3)V99 COMP-3.
           05  CONS-DT-ENTRADA       PIC 9(8).
           05  CONS-DT-CONTEMPLACAO  PIC 9(8).
           05  CONS-STATUS           PIC X(1).
           05  CONS-LANCE            PIC S9(9)V99 COMP-3.

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-CONS-CTRL.
           05  FS-CONS               PIC XX.
               88  FS-CONS-OK        VALUE '00'.
               88  FS-CONS-EOF       VALUE '10'.
               88  FS-CONS-NFD       VALUE '23'.
               88  FS-CONS-DUP       VALUE '22'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CONS-CONTINUAR    VALUE 'S'.
               88  CONS-PARAR        VALUE 'N'.
           05  WS-CONS-SEQ           PIC 9(12) VALUE ZEROS.

       01  WS-CONS-PLANOS.
      *    Imovel
           05  WS-IMO-VALOR-MIN      PIC S9(13)V99 COMP-3 VALUE 80000,00.
           05  WS-IMO-VALOR-MAX      PIC S9(13)V99 COMP-3 VALUE 500000,00.
           05  WS-IMO-TX-ADM         PIC 9(3)V99 COMP-3 VALUE 18,00.
           05  WS-IMO-PRAZO-MAX      PIC 9(4) COMP-3 VALUE 240.
      *    Veiculo
           05  WS-VEI-VALOR-MIN      PIC S9(13)V99 COMP-3 VALUE 30000,00.
           05  WS-VEI-VALOR-MAX      PIC S9(13)V99 COMP-3 VALUE 200000,00.
           05  WS-VEI-TX-ADM         PIC 9(3)V99 COMP-3 VALUE 15,00.
           05  WS-VEI-PRAZO-MAX      PIC 9(4) COMP-3 VALUE 84.
      *    Servico/outros
           05  WS-SRV-TX-ADM         PIC 9(3)V99 COMP-3 VALUE 12,00.
           05  WS-SRV-PRAZO-MAX      PIC 9(4) COMP-3 VALUE 60.

       01  WS-CONS-CALC.
           05  WS-CONS-TIPO-SEL      PIC X(5).
           05  WS-CONS-VALOR         PIC S9(13)V99 COMP-3.
           05  WS-CONS-PRAZO         PIC 9(4).
           05  WS-CONS-PARCELA-CAL   PIC S9(9)V99 COMP-3.
           05  WS-CONS-TX-CAL        PIC 9(3)V99 COMP-3.
           05  WS-CONS-TOTAL         PIC S9(13)V99 COMP-3.
           05  WS-CONS-CONTA-NUM     PIC 9(10).
           05  WS-CONS-ID-SEL        PIC 9(12).
           05  WS-CONS-LANCE-VAL     PIC S9(9)V99 COMP-3.
           05  WS-DIS-PARC           PIC ZZ.ZZZ.ZZZ,99-.
           05  WS-DIS-VAL            PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.
           05  WS-DIS-TOT            PIC ZZZ.ZZZ.ZZZ.ZZ9,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQCONS
           IF NOT FS-CONS-OK
               OPEN OUTPUT ARQCONS
               CLOSE ARQCONS
               OPEN I-O ARQCONS
           END-IF
           PERFORM 9900-CARREGAR-SEQ
           PERFORM 1000-MENU UNTIL CONS-PARAR
           CLOSE ARQCONS
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-CARREGAR-SEQ.
           MOVE 999999999999 TO CONS-ID
           START ARQCONS KEY <= CONS-ID
           READ ARQCONS PREVIOUS
           IF FS-CONS-OK
               MOVE CONS-ID TO WS-CONS-SEQ
           ELSE
               MOVE ZEROS TO WS-CONS-SEQ
           END-IF.

      *================================================================
       1000-MENU SECTION.
      *================================================================
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '           CONSORCIO'
           DISPLAY '========================================'
           DISPLAY ' 01. Aderir Consorcio Imovel'
           DISPLAY ' 02. Aderir Consorcio Veiculo'
           DISPLAY ' 03. Aderir Consorcio Servicos'
           DISPLAY ' 04. Consultar Cotas'
           DISPLAY ' 05. Oferecer Lance'
           DISPLAY ' 06. Historico de Contemplados'
           DISPLAY ' 07. Simulador de Consorcio'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-ADERIR-IMOVEL
               WHEN '02' PERFORM 3000-ADERIR-VEICULO
               WHEN '03' PERFORM 4000-ADERIR-SERVICO
               WHEN '04' PERFORM 5000-CONSULTAR-COTAS
               WHEN '05' PERFORM 6000-OFERECER-LANCE
               WHEN '06' PERFORM 7000-HISTORICO-CONTEMPL
               WHEN '07' PERFORM 8000-SIMULAR
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

      *================================================================
       2000-ADERIR-IMOVEL SECTION.
      *================================================================
       2000-INICIO.
           DISPLAY '--- CONSORCIO IMOBILIARIO ---'
           DISPLAY 'Conta para debito: '
           ACCEPT WS-CONS-CONTA-NUM
           DISPLAY 'Nome do participante: '
           ACCEPT WS-CONTA-TITULAR
           DISPLAY 'CPF: '
           ACCEPT WS-CONTA-CPF
           DISPLAY 'Valor do bem (80.000 - 500.000): '
           ACCEPT WS-CONS-VALOR
           IF WS-CONS-VALOR < WS-IMO-VALOR-MIN
           OR WS-CONS-VALOR > WS-IMO-VALOR-MAX
               DISPLAY 'VALOR FORA DO INTERVALO PERMITIDO'
               MOVE 3 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Prazo em meses (max 240): '
           ACCEPT WS-CONS-PRAZO
           IF WS-CONS-PRAZO > WS-IMO-PRAZO-MAX
               MOVE WS-IMO-PRAZO-MAX TO WS-CONS-PRAZO
               DISPLAY 'Prazo ajustado para maximo: 240 meses'
           END-IF
           MOVE WS-IMO-TX-ADM TO WS-CONS-TX-CAL
           PERFORM 9700-CALCULAR-PARCELA
           MOVE WS-CONS-PARCELA-CAL TO WS-DIS-PARC
           MOVE WS-CONS-VALOR TO WS-DIS-VAL
           MOVE WS-CONS-TOTAL TO WS-DIS-TOT
           DISPLAY 'Valor do bem:       R$ ' WS-DIS-VAL
           DISPLAY 'Parcela mensal:     R$ ' WS-DIS-PARC
           DISPLAY 'Total a pagar:      R$ ' WS-DIS-TOT
           DISPLAY 'Taxa adm (18%):     ' WS-CONS-TX-CAL '%'
           DISPLAY 'Prazo: ' WS-CONS-PRAZO ' meses'
           DISPLAY 'Assembleia: toda ultima sexta do mes'
           DISPLAY 'Confirmar adesao? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'IMOV' TO WS-CONS-TIPO-SEL
               PERFORM 9800-GRAVAR-COTA
               DISPLAY 'COTA ATIVADA! ID: ' WS-CONS-ID-SEL
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ADESAO CANCELADA'
           END-IF.

      *================================================================
       3000-ADERIR-VEICULO SECTION.
      *================================================================
       3000-INICIO.
           DISPLAY '--- CONSORCIO DE VEICULOS ---'
           DISPLAY 'Conta para debito: '
           ACCEPT WS-CONS-CONTA-NUM
           DISPLAY 'Nome do participante: '
           ACCEPT WS-CONTA-TITULAR
           DISPLAY 'CPF: '
           ACCEPT WS-CONTA-CPF
           DISPLAY 'Valor do veiculo (30.000 - 200.000): '
           ACCEPT WS-CONS-VALOR
           IF WS-CONS-VALOR < WS-VEI-VALOR-MIN
           OR WS-CONS-VALOR > WS-VEI-VALOR-MAX
               DISPLAY 'VALOR FORA DO INTERVALO'
               MOVE 3 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Prazo em meses (max 84): '
           ACCEPT WS-CONS-PRAZO
           IF WS-CONS-PRAZO > WS-VEI-PRAZO-MAX
               MOVE WS-VEI-PRAZO-MAX TO WS-CONS-PRAZO
           END-IF
           MOVE WS-VEI-TX-ADM TO WS-CONS-TX-CAL
           PERFORM 9700-CALCULAR-PARCELA
           MOVE WS-CONS-PARCELA-CAL TO WS-DIS-PARC
           MOVE WS-CONS-VALOR TO WS-DIS-VAL
           DISPLAY 'Valor do bem:   R$ ' WS-DIS-VAL
           DISPLAY 'Parcela mensal: R$ ' WS-DIS-PARC
           DISPLAY 'Taxa adm (15%) incluida nas parcelas'
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'VEIC' TO WS-CONS-TIPO-SEL
               PERFORM 9800-GRAVAR-COTA
               DISPLAY 'COTA ATIVADA! ID: ' WS-CONS-ID-SEL
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ADESAO CANCELADA'
           END-IF.

      *================================================================
       4000-ADERIR-SERVICO SECTION.
      *================================================================
       4000-INICIO.
           DISPLAY '--- CONSORCIO DE SERVICOS ---'
           DISPLAY 'Ex: Reforma, Educacao, Viagem, Cirurgia'
           DISPLAY 'Conta: '
           ACCEPT WS-CONS-CONTA-NUM
           DISPLAY 'Nome: '
           ACCEPT WS-CONTA-TITULAR
           DISPLAY 'CPF: '
           ACCEPT WS-CONTA-CPF
           DISPLAY 'Valor desejado: '
           ACCEPT WS-CONS-VALOR
           DISPLAY 'Prazo em meses (max 60): '
           ACCEPT WS-CONS-PRAZO
           IF WS-CONS-PRAZO > WS-SRV-PRAZO-MAX
               MOVE WS-SRV-PRAZO-MAX TO WS-CONS-PRAZO
           END-IF
           MOVE WS-SRV-TX-ADM TO WS-CONS-TX-CAL
           PERFORM 9700-CALCULAR-PARCELA
           MOVE WS-CONS-PARCELA-CAL TO WS-DIS-PARC
           DISPLAY 'Parcela mensal: R$ ' WS-DIS-PARC
           DISPLAY 'Confirmar? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'SERV' TO WS-CONS-TIPO-SEL
               PERFORM 9800-GRAVAR-COTA
               DISPLAY 'COTA ATIVADA! ID: ' WS-CONS-ID-SEL
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ADESAO CANCELADA'
           END-IF.

      *================================================================
       5000-CONSULTAR-COTAS SECTION.
      *================================================================
       5000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-CONS-CONTA-NUM
           DISPLAY '========================================'
           DISPLAY ' SUAS COTAS DE CONSORCIO'
           DISPLAY ' ID            Tipo  Parcela     Status'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO CONS-ID
           START ARQCONS KEY >= CONS-ID
           PERFORM UNTIL FS-CONS-EOF
               READ ARQCONS NEXT
               IF FS-CONS-OK
                   IF CONS-CONTA = WS-CONS-CONTA-NUM
                       MOVE CONS-PARCELA TO WS-DIS-PARC
                       DISPLAY CONS-ID ' '
                               CONS-TIPO '  R$ '
                               WS-DIS-PARC '  '
                               CONS-STATUS
                               ' (' CONS-PARCELAS-PAGAS
                               '/' CONS-PRAZO-MESES ')'
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       6000-OFERECER-LANCE SECTION.
      *================================================================
       6000-INICIO.
           DISPLAY '--- OFERECER LANCE ---'
           DISPLAY 'ID da cota: '
           ACCEPT WS-CONS-ID-SEL
           MOVE WS-CONS-ID-SEL TO CONS-ID
           READ ARQCONS KEY IS CONS-ID
           IF FS-CONS-NFD
               DISPLAY 'COTA NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF CONS-STATUS NOT = 'A'
               DISPLAY 'COTA NAO ATIVA OU JA CONTEMPLADA'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE CONS-VALOR-BEM TO WS-DIS-VAL
           DISPLAY 'Bem: ' CONS-TIPO ' / R$ ' WS-DIS-VAL
           DISPLAY 'Valor do lance (% ou R$): '
           ACCEPT WS-CONS-LANCE-VAL
           IF WS-CONS-LANCE-VAL > CONS-LANCE
               MOVE WS-CONS-LANCE-VAL TO CONS-LANCE
               REWRITE REG-CONS
               DISPLAY 'LANCE REGISTRADO PARA PROXIMA ASSEMBLEIA!'
               DISPLAY 'Valor: R$ ' WS-CONS-LANCE-VAL
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'LANCE DEVE SER MAIOR QUE O ATUAL'
               MOVE 3 TO LS-CODIGO
           END-IF.

      *================================================================
       7000-HISTORICO-CONTEMPL SECTION.
      *================================================================
       7000-INICIO.
           DISPLAY '========================================'
           DISPLAY ' CONTEMPLADOS NO GRUPO'
           DISPLAY ' ID            Tipo   Data'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO CONS-ID
           START ARQCONS KEY >= CONS-ID
           PERFORM UNTIL FS-CONS-EOF
               READ ARQCONS NEXT
               IF FS-CONS-OK
                   IF CONS-STATUS = 'C'
                       DISPLAY CONS-ID ' '
                               CONS-TIPO ' '
                               CONS-DT-CONTEMPLACAO
                   END-IF
               END-IF
           END-PERFORM
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       8000-SIMULAR SECTION.
      *================================================================
       8000-INICIO.
           DISPLAY '--- SIMULADOR DE CONSORCIO ---'
           DISPLAY 'Tipo (IMOV/VEIC/SERV): '
           ACCEPT WS-CONS-TIPO-SEL
           DISPLAY 'Valor do bem: '
           ACCEPT WS-CONS-VALOR
           DISPLAY 'Prazo (meses): '
           ACCEPT WS-CONS-PRAZO
           EVALUATE WS-CONS-TIPO-SEL
               WHEN 'IMOV' MOVE WS-IMO-TX-ADM TO WS-CONS-TX-CAL
               WHEN 'VEIC' MOVE WS-VEI-TX-ADM TO WS-CONS-TX-CAL
               WHEN OTHER  MOVE WS-SRV-TX-ADM TO WS-CONS-TX-CAL
           END-EVALUATE
           PERFORM 9700-CALCULAR-PARCELA
           MOVE WS-CONS-VALOR TO WS-DIS-VAL
           MOVE WS-CONS-PARCELA-CAL TO WS-DIS-PARC
           MOVE WS-CONS-TOTAL TO WS-DIS-TOT
           DISPLAY '========================================'
           DISPLAY ' SIMULACAO CONSORCIO ' WS-CONS-TIPO-SEL
           DISPLAY '========================================'
           DISPLAY ' Valor do bem:    R$ ' WS-DIS-VAL
           DISPLAY ' Prazo:           ' WS-CONS-PRAZO ' meses'
           DISPLAY ' Taxa adm:        ' WS-CONS-TX-CAL '%'
           DISPLAY ' Parcela mensal:  R$ ' WS-DIS-PARC
           DISPLAY ' Total a pagar:   R$ ' WS-DIS-TOT
           DISPLAY ' Sem juros! Correcao monetaria apenas'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

      *================================================================
       9700-CALCULAR-PARCELA.
      *================================================================
      *    Parcela = (Valor + Taxa_adm%) / Prazo
           COMPUTE WS-CONS-TOTAL ROUNDED =
               WS-CONS-VALOR * (1 + WS-CONS-TX-CAL / 100)
           COMPUTE WS-CONS-PARCELA-CAL ROUNDED =
               WS-CONS-TOTAL / WS-CONS-PRAZO.

      *================================================================
       9800-GRAVAR-COTA.
      *================================================================
           ADD 1 TO WS-CONS-SEQ
           MOVE WS-CONS-SEQ TO CONS-ID
           MOVE WS-CONS-SEQ TO WS-CONS-ID-SEL
           MOVE WS-CONS-CONTA-NUM TO CONS-CONTA
           MOVE WS-CONS-TIPO-SEL TO CONS-TIPO
           MOVE WS-CONTA-TITULAR TO CONS-PARTICIPANTE
           MOVE WS-CONTA-CPF TO CONS-CPF
           MOVE WS-CONS-VALOR TO CONS-VALOR-BEM
           MOVE WS-CONS-PARCELA-CAL TO CONS-PARCELA
           MOVE WS-CONS-PRAZO TO CONS-PRAZO-MESES
           MOVE ZEROS TO CONS-PARCELAS-PAGAS
           MOVE WS-CONS-TX-CAL TO CONS-TX-ADM
           MOVE FUNCTION CURRENT-DATE(1:8) TO CONS-DT-ENTRADA
           MOVE ZEROS TO CONS-DT-CONTEMPLACAO
           MOVE 'A' TO CONS-STATUS
           MOVE ZEROS TO CONS-LANCE
           WRITE REG-CONS
           IF NOT FS-CONS-OK
               DISPLAY 'ERRO AO GRAVAR COTA: ' FS-CONS
               MOVE 9999 TO LS-CODIGO
           END-IF.

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
