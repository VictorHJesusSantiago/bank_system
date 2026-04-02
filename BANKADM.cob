      *===============================================================
      * BANKADM.COB - Modulo Administrativo
      *===============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKADM.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS ADM-CONTA-NUM
               FILE STATUS IS FS-CONTAS.

           SELECT ARQTRANS ASSIGN TO 'BANKTRAN.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS ADM-TRANS-ID
               FILE STATUS IS FS-TRANS.

           SELECT ARQCLIENTE ASSIGN TO 'BANKCUST.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS ADM-CLI-ID
               FILE STATUS IS FS-CLIENTE.

           SELECT ARQLOG ASSIGN TO 'BANKAUDT.LOG'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-LOG.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONTAS.
       01  REG-CONTA.
           05  ADM-CONTA-NUM         PIC 9(10).
           05  ADM-CONTA-AGENCIA     PIC 9(4).
           05  ADM-CONTA-DIGITO      PIC 9(1).
           05  ADM-CONTA-TIPO        PIC X(2).
           05  ADM-CONTA-STATUS      PIC X(1).
           05  ADM-CONTA-SALDO       PIC S9(13)V99 COMP-3.
           05  ADM-CONTA-LIMITE      PIC S9(11)V99 COMP-3.
           05  ADM-CONTA-TITULAR     PIC X(60).
           05  ADM-CONTA-CPF         PIC X(11).
           05  ADM-CONTA-EMAIL       PIC X(80).
           05  ADM-CONTA-TELEFONE    PIC X(15).
           05  ADM-CONTA-DT-ABERTURA PIC 9(8).
           05  ADM-CONTA-DT-ATUALIZACAO PIC 9(8).
           05  ADM-CONTA-SENHA-HASH  PIC X(64).

       FD  ARQTRANS.
       01  REG-TRANS.
           05  ADM-TRANS-ID          PIC 9(15).
           05  ADM-TRANS-CONTA-ORG   PIC 9(10).
           05  ADM-TRANS-CONTA-DEST  PIC 9(10).
           05  ADM-TRANS-TIPO        PIC X(3).
           05  ADM-TRANS-VALOR       PIC S9(13)V99 COMP-3.
           05  ADM-TRANS-DATA        PIC 9(8).
           05  ADM-TRANS-HORA        PIC 9(6).
           05  ADM-TRANS-DESCRICAO   PIC X(100).
           05  ADM-TRANS-STATUS      PIC X(1).
           05  ADM-TRANS-NSU         PIC 9(12).
           05  ADM-TRANS-CANAL       PIC X(10).

       FD  ARQCLIENTE.
       01  REG-CLIENTE.
           05  ADM-CLI-ID            PIC 9(10).
           05  ADM-CLI-NOME          PIC X(60).
           05  ADM-CLI-CPF           PIC X(14).
           05  ADM-CLI-RG            PIC X(15).
           05  ADM-CLI-DT-NASC       PIC 9(8).
           05  ADM-CLI-SEXO          PIC X(1).
           05  ADM-CLI-ESTADO-CIVIL  PIC X(2).
           05  ADM-CLI-PROFISSAO     PIC X(40).
           05  ADM-CLI-RENDA         PIC S9(11)V99 COMP-3.
           05  ADM-CLI-PERFIL-RISCO  PIC X(1).
           05  ADM-CLI-ENDERECO      PIC X(190).
           05  ADM-CLI-STATUS        PIC X(1).
           05  ADM-CLI-SCORE         PIC 9(4).

       FD  ARQLOG.
       01  REG-LOG                   PIC X(200).

       WORKING-STORAGE SECTION.
       01  WS-CTRL.
           05  FS-CONTAS             PIC XX.
               88  FS-EOF            VALUE '10'.
           05  FS-TRANS              PIC XX.
               88  FS-EOF-TRANS      VALUE '10'.
           05  FS-CLIENTE            PIC XX.
               88  FS-EOF-CLI        VALUE '10'.
           05  FS-LOG                PIC XX.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CONTINUAR         VALUE 'S'.
               88  PARAR             VALUE 'N'.

       01  WS-TOTAIS.
           05  WS-QTD-CONTAS         PIC 9(8) VALUE ZEROS.
           05  WS-QTD-TRANS          PIC 9(10) VALUE ZEROS.
           05  WS-QTD-CLIENTES       PIC 9(8) VALUE ZEROS.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL.
           PERFORM 1000-MENU UNTIL PARAR
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU.
           DISPLAY '----------------------------------------'
           DISPLAY ' ADMINISTRACAO'
           DISPLAY '----------------------------------------'
           DISPLAY ' 01. Estatisticas gerais'
           DISPLAY ' 02. Limpar arquivo de log'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01'
                   PERFORM 2000-ESTATISTICAS
               WHEN '02'
                   PERFORM 3000-LIMPAR-LOG
               WHEN '00'
                   MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER
                   DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-ESTATISTICAS.
           MOVE ZEROS TO WS-QTD-CONTAS WS-QTD-TRANS WS-QTD-CLIENTES

           OPEN INPUT ARQCONTAS
           MOVE ZEROS TO ADM-CONTA-NUM
           START ARQCONTAS KEY >= ADM-CONTA-NUM
           PERFORM UNTIL FS-EOF
               READ ARQCONTAS NEXT
               IF NOT FS-EOF
                   ADD 1 TO WS-QTD-CONTAS
               END-IF
           END-PERFORM
           CLOSE ARQCONTAS

           OPEN INPUT ARQTRANS
           MOVE ZEROS TO ADM-TRANS-ID
           START ARQTRANS KEY >= ADM-TRANS-ID
           PERFORM UNTIL FS-EOF-TRANS
               READ ARQTRANS NEXT
               IF NOT FS-EOF-TRANS
                   ADD 1 TO WS-QTD-TRANS
               END-IF
           END-PERFORM
           CLOSE ARQTRANS

           OPEN INPUT ARQCLIENTE
           MOVE ZEROS TO ADM-CLI-ID
           START ARQCLIENTE KEY >= ADM-CLI-ID
           PERFORM UNTIL FS-EOF-CLI
               READ ARQCLIENTE NEXT
               IF NOT FS-EOF-CLI
                   ADD 1 TO WS-QTD-CLIENTES
               END-IF
           END-PERFORM
           CLOSE ARQCLIENTE

           DISPLAY 'Contas:    ' WS-QTD-CONTAS
           DISPLAY 'Transacoes:' WS-QTD-TRANS
           DISPLAY 'Clientes:  ' WS-QTD-CLIENTES.

       3000-LIMPAR-LOG.
           OPEN OUTPUT ARQLOG
           CLOSE ARQLOG
           DISPLAY 'LOG LIMPO COM SUCESSO.'.
