       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKDOA.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQDOA ASSIGN TO 'BANKDOA.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS DOA-ID
               FILE STATUS IS FS-DOA.

           SELECT ARQBRIDGE ASSIGN TO WS-BR-OUTFILE
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-BRIDGE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQDOA.
       01  REG-DOA.
           05  DOA-ID                PIC 9(15).
           05  DOA-CONTA             PIC 9(10).
           05  DOA-INSTITUICAO       PIC X(50).
           05  DOA-CATEGORIA         PIC X(15).
           05  DOA-VALOR             PIC S9(9)V99 COMP-3.
           05  DOA-TIPO              PIC X(10).
           05  DOA-DATA              PIC 9(8).
           05  DOA-STATUS            PIC X(1).

       FD  ARQBRIDGE.
       01  REG-BRIDGE                PIC X(200).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-DOA-CTRL.
           05  FS-DOA                PIC XX.
               88  FS-DOA-OK         VALUE '00'.
               88  FS-DOA-EOF        VALUE '10'.
               88  FS-DOA-NFD        VALUE '23'.
           05  FS-BRIDGE             PIC XX.
               88  FS-BRIDGE-OK      VALUE '00'.
               88  FS-BRIDGE-EOF     VALUE '10'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  DOA-PARAR         VALUE 'N'.
           05  WS-DOA-SEQ            PIC 9(15) VALUE ZEROS.

       01  WS-BRIDGE.
           05  WS-BR-OUTFILE          PIC X(40).
           05  WS-BR-CMD              PIC X(250).
           05  WS-BR-CONTA-E          PIC Z(9)9.
           05  WS-BR-ID-E             PIC Z(14)9.
           05  WS-BR-VALOR-INT-N      PIC 9(11).
           05  WS-BR-VALOR-INT-E      PIC Z(10)9.
           05  WS-BR-VALOR-DEC        PIC 99.
           05  WS-BR-VALOR-STR        PIC X(20).
           05  WS-BR-LINE             PIC X(200).
           05  WS-BR-KEY              PIC X(30).
           05  WS-BR-VAL              PIC X(160).
           05  WS-BR-OK               PIC 9 VALUE 0.
           05  WS-BR-ERROR            PIC X(150) VALUE SPACES.
           05  WS-BR-KIND             PIC X(20).

       01  WS-DOA-CALC.
           05  WS-DOA-CONTA-NUM      PIC 9(10).
           05  WS-DOA-ID-SEL         PIC 9(15).
           05  WS-DOA-CTR            PIC 9(6) COMP-3.
           05  WS-DOA-TOTAL-ANO      PIC S9(11)V99 COMP-3.
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQDOA
           IF NOT FS-DOA-OK
               OPEN OUTPUT ARQDOA
               CLOSE ARQDOA
               OPEN I-O ARQDOA
           END-IF
           PERFORM 9900-SEQ
           PERFORM 1000-MENU UNTIL DOA-PARAR
           CLOSE ARQDOA
           MOVE 0 TO LS-CODIGO
           GOBACK.

       9900-SEQ.
           MOVE 999999999999999 TO DOA-ID
           START ARQDOA KEY <= DOA-ID
           READ ARQDOA PREVIOUS
           IF FS-DOA-OK
               MOVE DOA-ID TO WS-DOA-SEQ
           ELSE
               MOVE ZEROS TO WS-DOA-SEQ
           END-IF.

       1000-MENU SECTION.
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '   DOACOES E CONTRIBUICOES SOCIAIS'
           DISPLAY '========================================'
           DISPLAY ' 01. Fazer Doacao'
           DISPLAY ' 02. Configurar Doacao Recorrente'
           DISPLAY ' 03. Consultar Historico de Doacoes'
           DISPLAY ' 04. Emitir Recibo (Dedutivel do IR)'
           DISPLAY ' 05. Instituicoes Parceiras'
           DISPLAY ' 06. Cancelar Doacao Recorrente'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-DOAR
               WHEN '02' PERFORM 3000-RECORRENTE
               WHEN '03' PERFORM 4000-HISTORICO
               WHEN '04' PERFORM 5000-RECIBO
               WHEN '05' PERFORM 6000-PARCEIRAS
               WHEN '06' PERFORM 7000-CANCELAR
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-DOAR SECTION.
       2000-INICIO.
           DISPLAY '--- FAZER DOACAO ---'
           DISPLAY 'Conta: '
           ACCEPT WS-DOA-CONTA-NUM
           DISPLAY 'Instituicao beneficiada: '
           ACCEPT DOA-INSTITUICAO
           DISPLAY 'Categoria (SAUDE/EDUCACAO/MEIO-AMBIENTE/'
           DISPLAY '           ASSISTENCIA-SOCIAL/CULTURA): '
           ACCEPT DOA-CATEGORIA
           DISPLAY 'Valor da doacao (R$): '
           ACCEPT DOA-VALOR
           ADD 1 TO WS-DOA-SEQ
           MOVE WS-DOA-SEQ TO DOA-ID
           MOVE WS-DOA-CONTA-NUM TO DOA-CONTA
           MOVE 'UNICA' TO DOA-TIPO
           MOVE FUNCTION CURRENT-DATE(1:8) TO DOA-DATA
           MOVE 'C' TO DOA-STATUS
           MOVE 'DONATION' TO WS-BR-KIND
           PERFORM 2100-DEBITAR-RAZAO
           IF WS-BR-OK NOT = 1
               DISPLAY 'FALHA NO RAZAO CENTRAL: ' WS-BR-ERROR
               MOVE 9998 TO LS-CODIGO
               EXIT SECTION
           END-IF
           WRITE REG-DOA
           IF FS-DOA-OK
               MOVE DOA-VALOR TO WS-DIS
               DISPLAY 'DOACAO REALIZADA COM SUCESSO!'
               DISPLAY ' Comprovante: ' DOA-ID
               DISPLAY ' Valor: R$ ' WS-DIS
               DISPLAY ' Obrigado por contribuir!'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO: ' FS-DOA
               MOVE 9999 TO LS-CODIGO
           END-IF.

       2100-DEBITAR-RAZAO.
           MOVE DOA-CONTA TO WS-BR-CONTA-E
           MOVE DOA-ID TO WS-BR-ID-E
           COMPUTE WS-BR-VALOR-INT-N = FUNCTION INTEGER-PART(DOA-VALOR)
           COMPUTE WS-BR-VALOR-DEC =
               FUNCTION INTEGER((DOA-VALOR - WS-BR-VALOR-INT-N) * 100)
           MOVE WS-BR-VALOR-INT-N TO WS-BR-VALOR-INT-E
           MOVE SPACES TO WS-BR-VALOR-STR
           STRING FUNCTION TRIM(WS-BR-VALOR-INT-E) DELIMITED SIZE
                  '.' DELIMITED SIZE
                  WS-BR-VALOR-DEC DELIMITED SIZE
                  INTO WS-BR-VALOR-STR
           MOVE SPACES TO WS-BR-OUTFILE
           STRING 'BANKTMPO-' DOA-ID '.OUT' DELIMITED SIZE
               INTO WS-BR-OUTFILE
           MOVE SPACES TO WS-BR-CMD
           STRING 'python3 bank_core_cli.py settle DOA '
                  FUNCTION TRIM(WS-BR-KIND) ' '
                  FUNCTION TRIM(WS-BR-CONTA-E) ' '
                  FUNCTION TRIM(WS-BR-VALOR-STR) ' '
                  FUNCTION TRIM(WS-BR-ID-E)
                  ' --cobol-out ' FUNCTION TRIM(WS-BR-OUTFILE)
                  DELIMITED SIZE INTO WS-BR-CMD
           CALL 'SYSTEM' USING WS-BR-CMD
           MOVE 0 TO WS-BR-OK
           MOVE SPACES TO WS-BR-ERROR
           OPEN INPUT ARQBRIDGE
           IF FS-BRIDGE-OK
               PERFORM UNTIL FS-BRIDGE-EOF
                   READ ARQBRIDGE INTO WS-BR-LINE
                   IF NOT FS-BRIDGE-EOF
                       MOVE SPACES TO WS-BR-KEY WS-BR-VAL
                       UNSTRING WS-BR-LINE DELIMITED BY '='
                           INTO WS-BR-KEY WS-BR-VAL
                       IF FUNCTION TRIM(WS-BR-KEY) = 'OK'
                           IF FUNCTION TRIM(WS-BR-VAL) = '1'
                               MOVE 1 TO WS-BR-OK
                           END-IF
                       END-IF
                       IF FUNCTION TRIM(WS-BR-KEY) = 'ERROR'
                           MOVE FUNCTION TRIM(WS-BR-VAL) TO WS-BR-ERROR
                       END-IF
                   END-IF
               END-PERFORM
               CLOSE ARQBRIDGE
           END-IF.

       3000-RECORRENTE SECTION.
       3000-INICIO.
           DISPLAY '--- CONFIGURAR DOACAO RECORRENTE ---'
           DISPLAY 'Conta: '
           ACCEPT WS-DOA-CONTA-NUM
           DISPLAY 'Instituicao beneficiada: '
           ACCEPT DOA-INSTITUICAO
           DISPLAY 'Categoria (SAUDE/EDUCACAO/MEIO-AMBIENTE/'
           DISPLAY '           ASSISTENCIA-SOCIAL/CULTURA): '
           ACCEPT DOA-CATEGORIA
           DISPLAY 'Valor mensal (R$): '
           ACCEPT DOA-VALOR
           ADD 1 TO WS-DOA-SEQ
           MOVE WS-DOA-SEQ TO DOA-ID
           MOVE WS-DOA-CONTA-NUM TO DOA-CONTA
           MOVE 'RECORRENTE' TO DOA-TIPO
           MOVE FUNCTION CURRENT-DATE(1:8) TO DOA-DATA
           MOVE 'A' TO DOA-STATUS
           WRITE REG-DOA
           IF FS-DOA-OK
               MOVE DOA-VALOR TO WS-DIS
               DISPLAY 'DOACAO RECORRENTE CONFIGURADA!'
               DISPLAY ' ID: ' DOA-ID
               DISPLAY ' Debito mensal de R$ ' WS-DIS
               DISPLAY ' a partir do proximo mes'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO: ' FS-DOA
               MOVE 9999 TO LS-CODIGO
           END-IF.

       4000-HISTORICO SECTION.
       4000-INICIO.
           DISPLAY 'Conta: '
           ACCEPT WS-DOA-CONTA-NUM
           MOVE ZEROS TO WS-DOA-CTR WS-DOA-TOTAL-ANO
           DISPLAY '========================================'
           DISPLAY ' HISTORICO DE DOACOES - CONTA '
                   WS-DOA-CONTA-NUM
           DISPLAY ' Data      Instituicao        Valor    Tipo'
           DISPLAY '----------------------------------------'
           MOVE ZEROS TO DOA-ID
           START ARQDOA KEY >= DOA-ID
           PERFORM UNTIL FS-DOA-EOF
               READ ARQDOA NEXT
               IF FS-DOA-OK
                   IF DOA-CONTA = WS-DOA-CONTA-NUM
                       MOVE DOA-VALOR TO WS-DIS
                       DISPLAY DOA-DATA ' '
                               DOA-INSTITUICAO(1:18) ' R$ '
                               WS-DIS ' ' DOA-TIPO(1:10)
                       ADD 1 TO WS-DOA-CTR
                       ADD DOA-VALOR TO WS-DOA-TOTAL-ANO
                   END-IF
               END-IF
           END-PERFORM
           MOVE WS-DOA-TOTAL-ANO TO WS-DIS
           DISPLAY '----------------------------------------'
           DISPLAY ' Total de doacoes: ' WS-DOA-CTR
           DISPLAY ' Valor total doado: R$ ' WS-DIS
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       5000-RECIBO SECTION.
       5000-INICIO.
           DISPLAY 'Numero do comprovante: '
           ACCEPT WS-DOA-ID-SEL
           MOVE WS-DOA-ID-SEL TO DOA-ID
           READ ARQDOA KEY IS DOA-ID
           IF FS-DOA-NFD
               DISPLAY 'DOACAO NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           MOVE DOA-VALOR TO WS-DIS
           DISPLAY '========================================'
           DISPLAY ' RECIBO DE DOACAO - DEDUTIVEL DO IR'
           DISPLAY '----------------------------------------'
           DISPLAY ' Numero: ' DOA-ID
           DISPLAY ' Instituicao: ' DOA-INSTITUICAO(1:40)
           DISPLAY ' Categoria: ' DOA-CATEGORIA
           DISPLAY ' Data: ' DOA-DATA
           DISPLAY ' Valor: R$ ' WS-DIS
           DISPLAY '----------------------------------------'
           DISPLAY ' Use este numero na declaracao anual de IR'
           DISPLAY ' (Doacoes a fundos do idoso/crianca/cultura'
           DISPLAY '  podem ser deduzidas conforme legislacao)'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       6000-PARCEIRAS SECTION.
       6000-INICIO.
           DISPLAY '========================================'
           DISPLAY ' INSTITUICOES PARCEIRAS EM DESTAQUE'
           DISPLAY '----------------------------------------'
           DISPLAY ' - Fundo Municipal dos Direitos da Crianca'
           DISPLAY ' - Fundo do Idoso'
           DISPLAY ' - Hospitais filantropicos (Saude)'
           DISPLAY ' - ONGs de Educacao e Reflorestamento'
           DISPLAY ' - Instituicoes de Assistencia Social'
           DISPLAY ' - Projetos culturais incentivados (Lei Rouanet)'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       7000-CANCELAR SECTION.
       7000-INICIO.
           DISPLAY 'ID da Doacao Recorrente: '
           ACCEPT WS-DOA-ID-SEL
           MOVE WS-DOA-ID-SEL TO DOA-ID
           READ ARQDOA KEY IS DOA-ID
           IF FS-DOA-NFD
               DISPLAY 'REGISTRO NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           IF DOA-TIPO NOT = 'RECORRENTE'
               DISPLAY 'ESTA DOACAO NAO E RECORRENTE'
               MOVE 4 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Confirmar cancelamento? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'X' TO DOA-STATUS
               REWRITE REG-DOA
               DISPLAY 'DOACAO RECORRENTE CANCELADA'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO ABORTADA'
           END-IF.

       9999-FIM.
           EXIT PROGRAM.
