      *===============================================================
      * BANKCRM.COB - Modulo de Gestao de Clientes
      *===============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKCRM.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCLIENTE ASSIGN TO 'BANKCUST.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS CRM-CLI-ID
               ALTERNATE RECORD KEY IS CRM-CLI-CPF
               FILE STATUS IS FS-CLIENTE.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCLIENTE.
       01  REG-CLIENTE.
           05  CRM-CLI-ID            PIC 9(10).
           05  CRM-CLI-NOME          PIC X(60).
           05  CRM-CLI-CPF           PIC X(14).
           05  CRM-CLI-RG            PIC X(15).
           05  CRM-CLI-DT-NASC       PIC 9(8).
           05  CRM-CLI-SEXO          PIC X(1).
           05  CRM-CLI-ESTADO-CIVIL  PIC X(2).
           05  CRM-CLI-PROFISSAO     PIC X(40).
           05  CRM-CLI-RENDA         PIC S9(11)V99 COMP-3.
           05  CRM-CLI-PERFIL-RISCO  PIC X(1).
           05  CRM-CLI-ENDERECO.
               10  CRM-CLI-LOGRADOURO PIC X(60).
               10  CRM-CLI-NUMERO    PIC X(10).
               10  CRM-CLI-COMPL     PIC X(30).
               10  CRM-CLI-BAIRRO    PIC X(40).
               10  CRM-CLI-CIDADE    PIC X(40).
               10  CRM-CLI-ESTADO    PIC X(2).
               10  CRM-CLI-CEP       PIC X(8).
           05  CRM-CLI-STATUS        PIC X(1).
           05  CRM-CLI-SCORE-CREDITO PIC 9(4).

       WORKING-STORAGE SECTION.
       01  WS-CTRL.
           05  FS-CLIENTE            PIC XX.
               88  FS-OK             VALUE '00'.
               88  FS-EOF            VALUE '10'.
               88  FS-NFD            VALUE '23'.
               88  FS-DUP            VALUE '22'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CONTINUAR         VALUE 'S'.
               88  PARAR             VALUE 'N'.
           05  WS-BUSCA-ID           PIC 9(10).
           05  WS-CONTADOR           PIC 9(6) VALUE ZEROS.

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL.
           OPEN I-O ARQCLIENTE
           IF FS-CLIENTE = '35'
               OPEN OUTPUT ARQCLIENTE
               CLOSE ARQCLIENTE
               OPEN I-O ARQCLIENTE
           END-IF
           PERFORM 1000-MENU UNTIL PARAR
           CLOSE ARQCLIENTE
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU.
           DISPLAY '----------------------------------------'
           DISPLAY ' GESTAO DE CLIENTES'
           DISPLAY '----------------------------------------'
           DISPLAY ' 01. Cadastrar cliente (completo)'
           DISPLAY ' 02. Consultar cliente por ID'
           DISPLAY ' 03. Atualizar cadastro'
           DISPLAY ' 04. Inativar cliente'
           DISPLAY ' 05. Listar clientes'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01'
                   PERFORM 2000-CADASTRAR
               WHEN '02'
                   PERFORM 3000-CONSULTAR
               WHEN '03'
                   PERFORM 4000-ATUALIZAR
               WHEN '04'
                   PERFORM 5000-INATIVAR
               WHEN '05'
                   PERFORM 6000-LISTAR
               WHEN '00'
                   MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER
                   DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-CADASTRAR.
           DISPLAY 'ID do cliente: '
           ACCEPT CRM-CLI-ID
           DISPLAY 'Nome: '
           ACCEPT CRM-CLI-NOME
           DISPLAY 'CPF: '
           ACCEPT CRM-CLI-CPF
           DISPLAY 'RG: '
           ACCEPT CRM-CLI-RG
           DISPLAY 'Data nasc (AAAAMMDD): '
           ACCEPT CRM-CLI-DT-NASC
           DISPLAY 'Sexo (M/F/O): '
           ACCEPT CRM-CLI-SEXO
           DISPLAY 'Estado civil (2 chars): '
           ACCEPT CRM-CLI-ESTADO-CIVIL
           DISPLAY 'Profissao: '
           ACCEPT CRM-CLI-PROFISSAO
           DISPLAY 'Renda: '
           ACCEPT CRM-CLI-RENDA
           DISPLAY 'Perfil risco (C/M/A): '
           ACCEPT CRM-CLI-PERFIL-RISCO
           DISPLAY 'Email/Contato: '
           ACCEPT CRM-CLI-LOGRADOURO
           DISPLAY 'Telefone: '
           ACCEPT CRM-CLI-NUMERO
           DISPLAY 'Cidade: '
           ACCEPT CRM-CLI-CIDADE
           DISPLAY 'UF: '
           ACCEPT CRM-CLI-ESTADO
           DISPLAY 'CEP: '
           ACCEPT CRM-CLI-CEP
           MOVE 'A' TO CRM-CLI-STATUS
           MOVE 500 TO CRM-CLI-SCORE-CREDITO
           WRITE REG-CLIENTE
           IF FS-DUP
               DISPLAY 'ID JA EXISTENTE'
               MOVE 22 TO LS-CODIGO
           ELSE IF FS-OK
               DISPLAY 'CLIENTE CADASTRADO'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO AO CADASTRAR: ' FS-CLIENTE
               MOVE 9999 TO LS-CODIGO
           END-IF.

       3000-CONSULTAR.
           DISPLAY 'ID do cliente: '
           ACCEPT WS-BUSCA-ID
           MOVE WS-BUSCA-ID TO CRM-CLI-ID
           READ ARQCLIENTE KEY IS CRM-CLI-ID
           IF FS-NFD
               DISPLAY 'CLIENTE NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
           ELSE IF FS-OK
               DISPLAY 'Nome: ' CRM-CLI-NOME
               DISPLAY 'CPF: ' CRM-CLI-CPF
               DISPLAY 'RG: ' CRM-CLI-RG
               DISPLAY 'Nascimento: ' CRM-CLI-DT-NASC
               DISPLAY 'Profissao: ' CRM-CLI-PROFISSAO
               DISPLAY 'Renda: ' CRM-CLI-RENDA
               DISPLAY 'Perfil risco: ' CRM-CLI-PERFIL-RISCO
               DISPLAY 'Contato: ' CRM-CLI-LOGRADOURO
               DISPLAY 'Telefone: ' CRM-CLI-NUMERO
               DISPLAY 'Cidade: ' CRM-CLI-CIDADE ' - ' CRM-CLI-ESTADO
               DISPLAY 'Status: ' CRM-CLI-STATUS
               DISPLAY 'Score: ' CRM-CLI-SCORE-CREDITO
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO DE LEITURA: ' FS-CLIENTE
               MOVE 9999 TO LS-CODIGO
           END-IF.

       4000-ATUALIZAR.
           DISPLAY 'ID do cliente: '
           ACCEPT WS-BUSCA-ID
           MOVE WS-BUSCA-ID TO CRM-CLI-ID
           READ ARQCLIENTE KEY IS CRM-CLI-ID
           IF FS-NFD
               DISPLAY 'CLIENTE NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Novo Email: '
           ACCEPT CRM-CLI-LOGRADOURO
           DISPLAY 'Novo Telefone: '
           ACCEPT CRM-CLI-NUMERO
           DISPLAY 'Nova Profissao: '
           ACCEPT CRM-CLI-PROFISSAO
           DISPLAY 'Nova Renda: '
           ACCEPT CRM-CLI-RENDA
           DISPLAY 'Novo Perfil (C/M/A): '
           ACCEPT CRM-CLI-PERFIL-RISCO
           REWRITE REG-CLIENTE
           IF FS-OK
               DISPLAY 'CADASTRO ATUALIZADO'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO AO ATUALIZAR: ' FS-CLIENTE
               MOVE 9999 TO LS-CODIGO
           END-IF.

       5000-INATIVAR.
           DISPLAY 'ID do cliente: '
           ACCEPT WS-BUSCA-ID
           MOVE WS-BUSCA-ID TO CRM-CLI-ID
           READ ARQCLIENTE KEY IS CRM-CLI-ID
           IF FS-NFD
               DISPLAY 'CLIENTE NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE 'I' TO CRM-CLI-STATUS
           REWRITE REG-CLIENTE
           IF FS-OK
               DISPLAY 'CLIENTE INATIVADO'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ERRO AO INATIVAR: ' FS-CLIENTE
               MOVE 9999 TO LS-CODIGO
           END-IF.

       6000-LISTAR.
           MOVE ZEROS TO WS-CONTADOR
           MOVE ZEROS TO CRM-CLI-ID
           START ARQCLIENTE KEY >= CRM-CLI-ID
           PERFORM UNTIL FS-EOF
               READ ARQCLIENTE NEXT
               IF NOT FS-EOF
                   ADD 1 TO WS-CONTADOR
                   DISPLAY CRM-CLI-ID SPACE
                           CRM-CLI-NOME(1:20) SPACE
                           CRM-CLI-CPF(1:11) SPACE
                           CRM-CLI-STATUS SPACE
                           CRM-CLI-PERFIL-RISCO
               END-IF
           END-PERFORM
           DISPLAY 'Total de clientes: ' WS-CONTADOR.
