       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKNOTIF.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQNOTIF ASSIGN TO 'BANKNOTIF.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS NOTIF-CONTA
               FILE STATUS IS FS-NOTIF.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQNOTIF.
       01  REG-NOTIF.
           05  NOTIF-CONTA           PIC 9(10).
           05  NOTIF-EMAIL           PIC X(80).
           05  NOTIF-TELEFONE        PIC X(15).
           05  NOTIF-CANAL           PIC X(6).
           05  NOTIF-SALDO-MIN       PIC S9(11)V99 COMP-3.
           05  NOTIF-TRANSAC-ACIMA   PIC S9(11)V99 COMP-3.
           05  NOTIF-FLAG-COMPRAS    PIC X(1).
           05  NOTIF-FLAG-TRF        PIC X(1).
           05  NOTIF-FLAG-PIX        PIC X(1).
           05  NOTIF-FLAG-BOLETO     PIC X(1).
           05  NOTIF-FLAG-INVEST     PIC X(1).
           05  NOTIF-FLAG-LOGIN      PIC X(1).
           05  NOTIF-FLAG-LIMITE     PIC X(1).
           05  NOTIF-STATUS          PIC X(1).
           05  NOTIF-DT-CONFIG       PIC 9(8).

       WORKING-STORAGE SECTION.
       COPY BANKDATA.

       01  WS-NOTIF-CTRL.
           05  FS-NOTIF              PIC XX.
               88  FS-NOTIF-OK       VALUE '00'.
               88  FS-NOTIF-EOF      VALUE '10'.
               88  FS-NOTIF-NFD      VALUE '23'.
               88  FS-NOTIF-DUP      VALUE '22'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  NOTIF-PARAR       VALUE 'N'.

       01  WS-NOTIF-CALC.
           05  WS-NOTIF-CONTA-NUM    PIC 9(10).
           05  WS-DIS                PIC ZZZ.ZZZ.ZZZ,99-.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL SECTION.
       0000-INICIO.
           OPEN I-O ARQNOTIF
           IF NOT FS-NOTIF-OK
               OPEN OUTPUT ARQNOTIF
               CLOSE ARQNOTIF
               OPEN I-O ARQNOTIF
           END-IF
           PERFORM 1000-MENU UNTIL NOTIF-PARAR
           CLOSE ARQNOTIF
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU SECTION.
       1000-INICIO.
           DISPLAY '========================================'
           DISPLAY '      NOTIFICACOES E ALERTAS'
           DISPLAY '========================================'
           DISPLAY ' 01. Configurar Alertas da Conta'
           DISPLAY ' 02. Consultar Configuracao Atual'
           DISPLAY ' 03. Ativar/Desativar Alertas'
           DISPLAY ' 04. Testar Notificacao'
           DISPLAY ' 05. Desativar Todos os Alertas'
           DISPLAY ' 00. Voltar'
           DISPLAY '========================================'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01' PERFORM 2000-CONFIGURAR
               WHEN '02' PERFORM 3000-CONSULTAR
               WHEN '03' PERFORM 4000-ATIVAR-DESATIVAR
               WHEN '04' PERFORM 5000-TESTAR
               WHEN '05' PERFORM 6000-DESATIVAR-TUDO
               WHEN '00' MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-CONFIGURAR SECTION.
       2000-INICIO.
           DISPLAY '--- CONFIGURAR ALERTAS ---'
           DISPLAY 'Numero da conta: '
           ACCEPT WS-NOTIF-CONTA-NUM
           MOVE WS-NOTIF-CONTA-NUM TO NOTIF-CONTA
           READ ARQNOTIF KEY IS NOTIF-CONTA
           IF FS-NOTIF-NFD
               INITIALIZE REG-NOTIF
               MOVE WS-NOTIF-CONTA-NUM TO NOTIF-CONTA
               MOVE 'A' TO NOTIF-STATUS
           END-IF
           DISPLAY 'Email para notificacoes: '
           ACCEPT NOTIF-EMAIL
           DISPLAY 'Telefone (SMS): '
           ACCEPT NOTIF-TELEFONE
           DISPLAY 'Canal (EMAIL/SMS/AMBOS): '
           ACCEPT NOTIF-CANAL
           DISPLAY 'Alertar saldo abaixo de (R$): '
           ACCEPT NOTIF-SALDO-MIN
           DISPLAY 'Alertar transacoes acima de (R$): '
           ACCEPT NOTIF-TRANSAC-ACIMA
           DISPLAY 'Alertar compras? (S/N): '
           ACCEPT NOTIF-FLAG-COMPRAS
           DISPLAY 'Alertar transferencias? (S/N): '
           ACCEPT NOTIF-FLAG-TRF
           DISPLAY 'Alertar PIX? (S/N): '
           ACCEPT NOTIF-FLAG-PIX
           DISPLAY 'Alertar boletos? (S/N): '
           ACCEPT NOTIF-FLAG-BOLETO
           DISPLAY 'Alertar investimentos? (S/N): '
           ACCEPT NOTIF-FLAG-INVEST
           DISPLAY 'Alertar novos logins? (S/N): '
           ACCEPT NOTIF-FLAG-LOGIN
           DISPLAY 'Alertar alteracoes de limite? (S/N): '
           ACCEPT NOTIF-FLAG-LIMITE
           MOVE FUNCTION CURRENT-DATE(1:8) TO NOTIF-DT-CONFIG
           REWRITE REG-NOTIF
           IF FS-NOTIF-NFD
               WRITE REG-NOTIF
           END-IF
           DISPLAY 'ALERTAS CONFIGURADOS COM SUCESSO!'
           MOVE 0 TO LS-CODIGO.

       3000-CONSULTAR SECTION.
       3000-INICIO.
           DISPLAY 'Numero da conta: '
           ACCEPT WS-NOTIF-CONTA-NUM
           MOVE WS-NOTIF-CONTA-NUM TO NOTIF-CONTA
           READ ARQNOTIF KEY IS NOTIF-CONTA
           IF FS-NOTIF-NFD
               DISPLAY 'NENHUMA CONFIGURACAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY '========================================'
           DISPLAY ' CONFIGURACAO DE ALERTAS - ' NOTIF-CONTA
           DISPLAY '========================================'
           DISPLAY ' Email:  ' NOTIF-EMAIL(1:40)
           DISPLAY ' Fone:   ' NOTIF-TELEFONE
           DISPLAY ' Canal:  ' NOTIF-CANAL
           MOVE NOTIF-SALDO-MIN TO WS-DIS
           DISPLAY ' Alerta saldo < R$: ' WS-DIS
           MOVE NOTIF-TRANSAC-ACIMA TO WS-DIS
           DISPLAY ' Alerta transac > R$: ' WS-DIS
           DISPLAY '----------------------------------------'
           DISPLAY ' Compras:        ' NOTIF-FLAG-COMPRAS
           DISPLAY ' Transferencias: ' NOTIF-FLAG-TRF
           DISPLAY ' PIX:            ' NOTIF-FLAG-PIX
           DISPLAY ' Boletos:        ' NOTIF-FLAG-BOLETO
           DISPLAY ' Investimentos:  ' NOTIF-FLAG-INVEST
           DISPLAY ' Logins:         ' NOTIF-FLAG-LOGIN
           DISPLAY ' Limites:        ' NOTIF-FLAG-LIMITE
           DISPLAY '----------------------------------------'
           DISPLAY ' Status geral:   ' NOTIF-STATUS
           DISPLAY ' Configurado em: ' NOTIF-DT-CONFIG
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       4000-ATIVAR-DESATIVAR SECTION.
       4000-INICIO.
           DISPLAY 'Numero da conta: '
           ACCEPT WS-NOTIF-CONTA-NUM
           MOVE WS-NOTIF-CONTA-NUM TO NOTIF-CONTA
           READ ARQNOTIF KEY IS NOTIF-CONTA
           IF FS-NOTIF-NFD
               DISPLAY 'CONFIGURACAO NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Status atual: ' NOTIF-STATUS
           DISPLAY 'Novo status (A=Ativo I=Inativo): '
           ACCEPT NOTIF-STATUS
           REWRITE REG-NOTIF
           IF NOTIF-STATUS = 'A'
               DISPLAY 'ALERTAS ATIVADOS'
           ELSE
               DISPLAY 'ALERTAS SUSPENSOS'
           END-IF
           MOVE 0 TO LS-CODIGO.

       5000-TESTAR SECTION.
       5000-INICIO.
           DISPLAY 'Numero da conta: '
           ACCEPT WS-NOTIF-CONTA-NUM
           MOVE WS-NOTIF-CONTA-NUM TO NOTIF-CONTA
           READ ARQNOTIF KEY IS NOTIF-CONTA
           IF FS-NOTIF-NFD
               DISPLAY 'CONFIGURACAO NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY '========================================'
           DISPLAY ' SIMULACAO DE NOTIFICACAO'
           DISPLAY '========================================'
           IF NOTIF-CANAL = 'EMAIL' OR NOTIF-CANAL = 'AMBOS'
               DISPLAY ' [EMAIL] Para: ' NOTIF-EMAIL(1:40)
               DISPLAY ' Assunto: Alerta de movimentacao - Conta '
                       NOTIF-CONTA
               DISPLAY ' Corpo: Transacao de R$ 500,00 realizada.'
           END-IF
           IF NOTIF-CANAL = 'SMS' OR NOTIF-CANAL = 'AMBOS'
               DISPLAY ' [SMS] Para: ' NOTIF-TELEFONE
               DISPLAY ' Msg: Banco: Transacao R$500,00 em '
                       FUNCTION CURRENT-DATE(1:8)
           END-IF
           DISPLAY '========================================'
           DISPLAY ' Notificacao de teste enviada!'
           MOVE 0 TO LS-CODIGO.

       6000-DESATIVAR-TUDO SECTION.
       6000-INICIO.
           DISPLAY 'Numero da conta: '
           ACCEPT WS-NOTIF-CONTA-NUM
           MOVE WS-NOTIF-CONTA-NUM TO NOTIF-CONTA
           READ ARQNOTIF KEY IS NOTIF-CONTA
           IF FS-NOTIF-NFD
               DISPLAY 'CONFIGURACAO NAO ENCONTRADA'
               MOVE 2 TO LS-CODIGO
               EXIT SECTION
           END-IF
           DISPLAY 'Desativar TODOS os alertas? (S/N): '
           ACCEPT WS-OPCAO
           IF WS-OPCAO = 'S'
               MOVE 'I' TO NOTIF-STATUS
               MOVE 'N' TO NOTIF-FLAG-COMPRAS NOTIF-FLAG-TRF
               MOVE 'N' TO NOTIF-FLAG-PIX     NOTIF-FLAG-BOLETO
               MOVE 'N' TO NOTIF-FLAG-INVEST  NOTIF-FLAG-LOGIN
               MOVE 'N' TO NOTIF-FLAG-LIMITE
               REWRITE REG-NOTIF
               DISPLAY 'TODOS OS ALERTAS DESATIVADOS'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'OPERACAO CANCELADA'
           END-IF.

       9999-FIM.
           EXIT PROGRAM.
