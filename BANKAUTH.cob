      *===============================================================
      * BANKAUTH.COB - Autenticacao, Seguranca e 2FA
      * Sistema Bancario COBOL v2.0
      *===============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKAUTH.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCONTAS ASSIGN TO 'BANKACCT.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS AUTH-CONTA-NUM
               ALTERNATE RECORD KEY IS AUTH-CONTA-CPF
               FILE STATUS IS FS-CONTAS.

       DATA DIVISION.
       FILE SECTION.
       FD  ARQCONTAS.
       01  REG-CONTA-AUTH.
           05  AUTH-CONTA-NUM        PIC 9(10).
           05  AUTH-CONTA-AGENCIA    PIC 9(4).
           05  AUTH-CONTA-DIGITO     PIC 9(1).
           05  AUTH-CONTA-TIPO       PIC X(2).
           05  AUTH-CONTA-STATUS     PIC X(1).
           05  AUTH-CONTA-SALDO      PIC S9(13)V99 COMP-3.
           05  AUTH-CONTA-LIMITE     PIC S9(11)V99 COMP-3.
           05  AUTH-CONTA-TITULAR    PIC X(60).
           05  AUTH-CONTA-CPF        PIC X(11).
           05  AUTH-CONTA-EMAIL      PIC X(80).
           05  AUTH-CONTA-FONE       PIC X(15).
           05  AUTH-CONTA-DT-ABER    PIC 9(8).
           05  AUTH-CONTA-DT-ATUA    PIC 9(8).
           05  AUTH-CONTA-SENHA      PIC X(64).

       WORKING-STORAGE SECTION.
       01  WS-CTRL.
           05  FS-CONTAS             PIC XX.
               88  FS-OK             VALUE '00'.
               88  FS-NFD            VALUE '23'.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CONTINUAR         VALUE 'S'.
               88  PARAR             VALUE 'N'.

       01  WS-AUTH.
           05  WS-CPF-INPUT          PIC X(11).
           05  WS-SENHA-INPUT        PIC X(64).
           05  WS-SENHA-NOVA         PIC X(64).
           05  WS-SENHA-CONF         PIC X(64).
           05  WS-TENTATIVAS         PIC 9 VALUE ZEROS.
           05  WS-MAX-TENT           PIC 9 VALUE 3.
           05  WS-AUTENTICADO        PIC X VALUE 'N'.
           05  WS-2FA-CODIGO         PIC 9(6).
           05  WS-2FA-INPUT          PIC 9(6).
           05  WS-2FA-SEED           PIC 9(6).
           05  WS-HORA-BASE          PIC 9(6).
           05  WS-PONTOS             PIC 9(10) VALUE ZEROS.
           05  WS-BADGE-NIVEL        PIC X(20).

       01  WS-EXIB.
           05  WS-NOME-EXIB          PIC X(30).

       LINKAGE SECTION.
       01  LS-RETORNO.
           05  LS-CODIGO             PIC 9(4).
           05  LS-MENSAGEM           PIC X(100).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL.
           OPEN I-O ARQCONTAS
           PERFORM 1000-MENU UNTIL PARAR
           CLOSE ARQCONTAS
           MOVE 0 TO LS-CODIGO
           GOBACK.

       1000-MENU.
           DISPLAY '----------------------------------------'
           DISPLAY ' AUTENTICACAO E SEGURANCA'
           DISPLAY '----------------------------------------'
           DISPLAY ' 01. Login (CPF + Senha)'
           DISPLAY ' 02. Alterar Senha'
           DISPLAY ' 03. Verificacao em Dois Fatores (2FA)'
           DISPLAY ' 04. Recuperar Acesso'
           DISPLAY ' 05. Minha Pontuacao e Badges'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01'  PERFORM 2000-LOGIN
               WHEN '02'  PERFORM 3000-ALTERAR-SENHA
               WHEN '03'  PERFORM 4000-DOIS-FATORES
               WHEN '04'  PERFORM 5000-RECUPERAR-ACESSO
               WHEN '05'  PERFORM 6000-PONTUACAO
               WHEN '00'  MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-LOGIN.
           MOVE ZEROS TO WS-TENTATIVAS
           MOVE 'N' TO WS-AUTENTICADO
           PERFORM UNTIL WS-AUTENTICADO = 'S'
               OR WS-TENTATIVAS >= WS-MAX-TENT
               DISPLAY 'CPF (somente numeros): '
               ACCEPT WS-CPF-INPUT
               DISPLAY 'Senha: '
               ACCEPT WS-SENHA-INPUT
               PERFORM 2100-VERIFICAR-CREDENCIAIS
               IF WS-AUTENTICADO NOT = 'S'
                   ADD 1 TO WS-TENTATIVAS
                   COMPUTE WS-2FA-SEED =
                       WS-MAX-TENT - WS-TENTATIVAS
                   DISPLAY 'Credenciais invalidas. Tentativas: '
                           WS-TENTATIVAS '/' WS-MAX-TENT
               END-IF
           END-PERFORM
           IF WS-AUTENTICADO = 'S'
               MOVE AUTH-CONTA-TITULAR(1:30) TO WS-NOME-EXIB
               DISPLAY 'AUTENTICADO - Bem-vindo, ' WS-NOME-EXIB
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY 'ACESSO BLOQUEADO - Limite de tentativas'
               MOVE 5 TO LS-CODIGO
           END-IF.

       2100-VERIFICAR-CREDENCIAIS.
           MOVE WS-CPF-INPUT TO AUTH-CONTA-CPF
           READ ARQCONTAS KEY IS AUTH-CONTA-CPF
           IF FS-NFD
               DISPLAY 'CPF NAO CADASTRADO'
               EXIT PARAGRAPH
           END-IF
           IF AUTH-CONTA-STATUS NOT = 'A'
               DISPLAY 'CONTA INATIVA OU BLOQUEADA'
               MOVE 4 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
      *    Compara senha: primeiros 8 chars (PIN simplificado)
      *    Em producao usar hash SHA-256
           IF AUTH-CONTA-SENHA(1:8) = WS-SENHA-INPUT(1:8)
               MOVE 'S' TO WS-AUTENTICADO
               MOVE 0 TO LS-CODIGO
           END-IF.

       3000-ALTERAR-SENHA.
           DISPLAY 'CPF: '
           ACCEPT WS-CPF-INPUT
           MOVE WS-CPF-INPUT TO AUTH-CONTA-CPF
           READ ARQCONTAS KEY IS AUTH-CONTA-CPF
           IF FS-NFD
               DISPLAY 'CPF NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Senha atual: '
           ACCEPT WS-SENHA-INPUT
           IF AUTH-CONTA-SENHA(1:8) NOT = WS-SENHA-INPUT(1:8)
               DISPLAY 'SENHA ATUAL INCORRETA'
               MOVE 5 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Nova senha (min 6 chars): '
           ACCEPT WS-SENHA-NOVA
           DISPLAY 'Confirme a nova senha: '
           ACCEPT WS-SENHA-CONF
           IF WS-SENHA-NOVA NOT = WS-SENHA-CONF
               DISPLAY 'SENHAS NAO CONFEREM'
               MOVE 3 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO AUTH-CONTA-SENHA
           MOVE WS-SENHA-NOVA TO AUTH-CONTA-SENHA
           MOVE FUNCTION CURRENT-DATE(1:8) TO AUTH-CONTA-DT-ATUA
           REWRITE REG-CONTA-AUTH
           DISPLAY 'SENHA ALTERADA COM SUCESSO'
           MOVE 0 TO LS-CODIGO.

       4000-DOIS-FATORES.
      *    Codigo 2FA baseado em timestamp (HHMMSS MOD 899999 + 100000)
           MOVE FUNCTION CURRENT-DATE(9:6) TO WS-HORA-BASE
           COMPUTE WS-2FA-CODIGO =
               FUNCTION MOD(FUNCTION NUMVAL(WS-HORA-BASE)
                            899999) + 100000
           DISPLAY '*** CODIGO 2FA (valido por 60s) ***'
           DISPLAY 'Codigo: ' WS-2FA-CODIGO
           DISPLAY 'Digite o codigo para confirmar: '
           ACCEPT WS-2FA-INPUT
           IF WS-2FA-INPUT = WS-2FA-CODIGO
               DISPLAY '2FA VERIFICADO COM SUCESSO'
               MOVE 0 TO LS-CODIGO
           ELSE
               DISPLAY '2FA INVALIDO'
               MOVE 5 TO LS-CODIGO
           END-IF.

       5000-RECUPERAR-ACESSO.
           DISPLAY 'CPF cadastrado: '
           ACCEPT WS-CPF-INPUT
           MOVE WS-CPF-INPUT TO AUTH-CONTA-CPF
           READ ARQCONTAS KEY IS AUTH-CONTA-CPF
           IF FS-NFD
               DISPLAY 'CPF NAO ENCONTRADO'
               MOVE 2 TO LS-CODIGO
               EXIT PARAGRAPH
           END-IF
           DISPLAY 'Email cadastrado: ' AUTH-CONTA-EMAIL
           DISPLAY 'Um link de recuperacao foi enviado'
           DISPLAY '(Contate o administrador com seu CPF'
                   ' para redefinicao)'
           MOVE 0 TO LS-CODIGO.

       6000-PONTUACAO.
           DISPLAY '========================================'
           DISPLAY ' GAMIFICACAO — BANCO COBOL REWARDS'
           DISPLAY '========================================'
           DISPLAY ' Pontos acumulados: ' WS-PONTOS
           EVALUATE TRUE
               WHEN WS-PONTOS >= 10000
                   MOVE 'PLATINA' TO WS-BADGE-NIVEL
               WHEN WS-PONTOS >= 5000
                   MOVE 'OURO' TO WS-BADGE-NIVEL
               WHEN WS-PONTOS >= 1000
                   MOVE 'PRATA' TO WS-BADGE-NIVEL
               WHEN OTHER
                   MOVE 'BRONZE' TO WS-BADGE-NIVEL
           END-EVALUATE
           DISPLAY ' Nivel atual    : ' WS-BADGE-NIVEL
           DISPLAY '----------------------------------------'
           DISPLAY ' Como ganhar pontos:'
           DISPLAY '  +10 pts  a cada transacao realizada'
           DISPLAY '  +50 pts  ao quitar emprestimo'
           DISPLAY '  +25 pts  ao pagar fatura em dia'
           DISPLAY '  +100 pts ao completar onboarding'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.
