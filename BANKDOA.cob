      *================================================================
      * BANKDOA.COB - Doacoes e Contribuicoes Sociais
      * Sistema Bancario COBOL
      *================================================================
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

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-DOA-CTRL.
           05  FS-DOA                PIC XX.
               88  FS-DOA-OK         VALUE '00'.
               88  FS-DOA-EOF        VALUE '10'.
               88  FS-DOA-NFD        VALUE '23'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  DOA-PARAR         VALUE 'N'.
           05  WS-DOA-SEQ            PIC 9(15) VALUE ZEROS.

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

      *================================================================
       1000-MENU SECTION.
      *================================================================
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

      *================================================================
       2000-DOAR SECTION.
      *================================================================
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

      *================================================================
       3000-RECORRENTE SECTION.
      *================================================================
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

      *================================================================
       4000-HISTORICO SECTION.
      *================================================================
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

      *================================================================
       5000-RECIBO SECTION.
      *================================================================
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

      *================================================================
       6000-PARCEIRAS SECTION.
      *================================================================
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

      *================================================================
       7000-CANCELAR SECTION.
      *================================================================
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

      *================================================================
       9999-FIM.
      *================================================================
           EXIT PROGRAM.
