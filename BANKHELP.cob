      *===============================================================
      * BANKHELP.COB - Central de Ajuda, FAQ, Termos e Suporte
      * Sistema Bancario COBOL v2.0
      *===============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKHELP.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CTRL.
           05  WS-OPCAO              PIC X(2).
           05  WS-CONTINUAR          PIC X VALUE 'S'.
               88  CONTINUAR         VALUE 'S'.
               88  PARAR             VALUE 'N'.

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
           DISPLAY '========================================'
           DISPLAY ' CENTRAL DE AJUDA — BANCO COBOL'
           DISPLAY '========================================'
           DISPLAY ' 01. Perguntas Frequentes (FAQ)'
           DISPLAY ' 02. Guia de Uso Rapido'
           DISPLAY ' 03. Termos de Uso'
           DISPLAY ' 04. Politica de Privacidade'
           DISPLAY ' 05. Fale Conosco / Suporte'
           DISPLAY ' 06. Sobre o Sistema'
           DISPLAY ' 00. Voltar'
           ACCEPT WS-OPCAO
           EVALUATE WS-OPCAO
               WHEN '01'  PERFORM 2000-FAQ
               WHEN '02'  PERFORM 3000-GUIA
               WHEN '03'  PERFORM 4000-TERMOS
               WHEN '04'  PERFORM 5000-PRIVACIDADE
               WHEN '05'  PERFORM 6000-SUPORTE
               WHEN '06'  PERFORM 7000-SOBRE
               WHEN '00'  MOVE 'N' TO WS-CONTINUAR
               WHEN OTHER DISPLAY 'OPCAO INVALIDA'
           END-EVALUATE.

       2000-FAQ.
           DISPLAY '========================================'
           DISPLAY ' PERGUNTAS FREQUENTES (FAQ)'
           DISPLAY '========================================'
           DISPLAY ''
           DISPLAY 'P: Como abrir uma conta?'
           DISPLAY 'R: Acesse o menu Contas > Nova Conta.'
           DISPLAY '   Informe CPF, nome completo e senha.'
           DISPLAY ''
           DISPLAY 'P: Como fazer uma transferencia?'
           DISPLAY 'R: Menu Transferencias. Informe conta'
           DISPLAY '   destino, valor e tipo (TED/PIX/DOC).'
           DISPLAY ''
           DISPLAY 'P: Como solicitar emprestimo?'
           DISPLAY 'R: Menu Emprestimos > Solicitar.'
           DISPLAY '   Escolha o tipo e numero de parcelas.'
           DISPLAY ''
           DISPLAY 'P: Como emitir um cartao?'
           DISPLAY 'R: Menu Cartoes > Emitir Cartao.'
           DISPLAY '   Selecione debito ou credito.'
           DISPLAY ''
           DISPLAY 'P: Como ver meu cartao virtual?'
           DISPLAY 'R: Menu Cartoes > Cartao Virtual.'
           DISPLAY '   O numero e fixo e derivado da conta.'
           DISPLAY ''
           DISPLAY 'P: Como agendar pagamentos?'
           DISPLAY 'R: Menu Agendamentos > Agendar.'
           DISPLAY '   Defina data, recorrencia e tipo.'
           DISPLAY ''
           DISPLAY 'P: Como exportar meu extrato?'
           DISPLAY 'R: Menu Extrato > Exportar.'
           DISPLAY '   Escolha CSV, PDF, Excel, XML etc.'
           DISPLAY ''
           DISPLAY 'P: Esqueci minha senha. O que fazer?'
           DISPLAY 'R: Seguranca > Recuperar Acesso.'
           DISPLAY '   Use seu CPF cadastrado.'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       3000-GUIA.
           DISPLAY '========================================'
           DISPLAY ' GUIA DE USO RAPIDO'
           DISPLAY '========================================'
           DISPLAY ''
           DISPLAY '1. PRIMEIROS PASSOS'
           DISPLAY '   - Crie sua conta no menu principal'
           DISPLAY '   - Faca login com CPF + senha'
           DISPLAY '   - Complete o onboarding (+100 pts)'
           DISPLAY ''
           DISPLAY '2. OPERACOES BASICAS'
           DISPLAY '   [1] Contas     - Saldo e extrato'
           DISPLAY '   [2] Trans.     - Saques/depositos'
           DISPLAY '   [3] Transfer.  - TED/PIX/DOC'
           DISPLAY '   [4] Pagamentos - Boletos'
           DISPLAY ''
           DISPLAY '3. SERVICOS AVANCADOS'
           DISPLAY '   [A] Emprestimos   - Simular/solicitar'
           DISPLAY '   [B] Cartoes       - Emitir/gerenciar'
           DISPLAY '   [C] Agendamentos  - Programar'
           DISPLAY '   [H] Ajuda         - Esta tela'
           DISPLAY ''
           DISPLAY '4. SEGURANCA'
           DISPLAY '   - Nunca compartilhe sua senha'
           DISPLAY '   - Ative o 2FA em Seguranca > 2FA'
           DISPLAY '   - Bloqueie cartao se perder'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       4000-TERMOS.
           DISPLAY '========================================'
           DISPLAY ' TERMOS DE USO'
           DISPLAY '========================================'
           DISPLAY ''
           DISPLAY '1. ACEITE DOS TERMOS'
           DISPLAY '   Ao usar este sistema, voce concorda'
           DISPLAY '   com todos os termos aqui descritos.'
           DISPLAY ''
           DISPLAY '2. USO PERMITIDO'
           DISPLAY '   - Gerenciar suas proprias financas'
           DISPLAY '   - Realizar transacoes autorizadas'
           DISPLAY '   - Acessar seus dados pessoais'
           DISPLAY ''
           DISPLAY '3. USO PROIBIDO'
           DISPLAY '   - Tentativas de acesso nao autorizado'
           DISPLAY '   - Manipulacao de dados de terceiros'
           DISPLAY '   - Uso para atividades ilegais'
           DISPLAY ''
           DISPLAY '4. RESPONSABILIDADE'
           DISPLAY '   O banco nao se responsabiliza por'
           DISPLAY '   perdas decorrentes de uso indevido'
           DISPLAY '   das credenciais pelo usuario.'
           DISPLAY ''
           DISPLAY '5. ALTERACOES'
           DISPLAY '   Os termos podem ser alterados com'
           DISPLAY '   aviso previo de 30 dias.'
           DISPLAY ''
           DISPLAY 'Versao: 2.0 | Vigencia: 01/01/2026'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       5000-PRIVACIDADE.
           DISPLAY '========================================'
           DISPLAY ' POLITICA DE PRIVACIDADE'
           DISPLAY '========================================'
           DISPLAY ''
           DISPLAY '1. DADOS COLETADOS'
           DISPLAY '   - CPF, nome, e-mail, telefone'
           DISPLAY '   - Historico de transacoes'
           DISPLAY '   - Dados de acesso (IP, hora)'
           DISPLAY ''
           DISPLAY '2. USO DOS DADOS'
           DISPLAY '   - Prestacao dos servicos bancarios'
           DISPLAY '   - Prevencao a fraudes'
           DISPLAY '   - Cumprimento de obrigacoes legais'
           DISPLAY ''
           DISPLAY '3. COMPARTILHAMENTO'
           DISPLAY '   Dados nao sao vendidos a terceiros.'
           DISPLAY '   Compartilhamos apenas quando exigido'
           DISPLAY '   por ordem judicial ou lei.'
           DISPLAY ''
           DISPLAY '4. SEUS DIREITOS (LGPD)'
           DISPLAY '   - Acesso aos seus dados'
           DISPLAY '   - Correcao de dados incorretos'
           DISPLAY '   - Exclusao de dados (quando aplicavel)'
           DISPLAY '   - Portabilidade dos dados'
           DISPLAY ''
           DISPLAY '5. SEGURANCA'
           DISPLAY '   Dados armazenados com criptografia.'
           DISPLAY '   Senhas nunca sao armazenadas em'
           DISPLAY '   texto puro.'
           DISPLAY ''
           DISPLAY 'Conforme LGPD (Lei 13.709/2018)'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       6000-SUPORTE.
           DISPLAY '========================================'
           DISPLAY ' FALE CONOSCO / SUPORTE'
           DISPLAY '========================================'
           DISPLAY ''
           DISPLAY ' CANAIS DE ATENDIMENTO:'
           DISPLAY ''
           DISPLAY ' Central de Atendimento:'
           DISPLAY '   0800-000-COBOL (0800-000-2625)'
           DISPLAY '   Segunda a Sexta: 08h - 20h'
           DISPLAY '   Sabado: 09h - 14h'
           DISPLAY ''
           DISPLAY ' SAC (24 horas, 7 dias):'
           DISPLAY '   0800-000-0001'
           DISPLAY ''
           DISPLAY ' Ouvidoria:'
           DISPLAY '   0800-000-0002'
           DISPLAY '   Prazo de resposta: 10 dias uteis'
           DISPLAY ''
           DISPLAY ' E-mail:'
           DISPLAY '   suporte@bancocobol.com.br'
           DISPLAY ''
           DISPLAY ' Chat (via GUI):'
           DISPLAY '   Disponivel no aplicativo grafico'
           DISPLAY ''
           DISPLAY ' Endereco:'
           DISPLAY '   Av. COBOL, 3.1 - TI Finance'
           DISPLAY '   Sao Paulo, SP - CEP 01000-000'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.

       7000-SOBRE.
           DISPLAY '========================================'
           DISPLAY ' SOBRE O SISTEMA BANCARIO COBOL'
           DISPLAY '========================================'
           DISPLAY ''
           DISPLAY ' Nome:    Banco COBOL'
           DISPLAY ' Versao:  2.0 (2026)'
           DISPLAY ' Engine:  GnuCOBOL 3.x'
           DISPLAY ' GUI:     Python 3.x / tkinter'
           DISPLAY ''
           DISPLAY ' MODULOS:'
           DISPLAY '  BANKMAIN  - Orquestrador principal'
           DISPLAY '  BANKACCT  - Gestao de contas'
           DISPLAY '  BANKTRAN  - Transacoes'
           DISPLAY '  BANKTRF   - Transferencias'
           DISPLAY '  BANKPAY   - Pagamentos e boletos'
           DISPLAY '  BANKCRM   - Relacionamento cliente'
           DISPLAY '  BANKADM   - Administracao'
           DISPLAY '  BANKINV   - Investimentos'
           DISPLAY '  BANKREP   - Relatorios/extrato'
           DISPLAY '  BANKQRY   - Consultas'
           DISPLAY '  BANKLOAN  - Emprestimos'
           DISPLAY '  BANKCARD  - Cartoes'
           DISPLAY '  BANKSCHD  - Agendamentos'
           DISPLAY '  BANKAUTH  - Autenticacao/2FA'
           DISPLAY '  BANKHELP  - Ajuda e suporte'
           DISPLAY ''
           DISPLAY ' ARQUIVOS DE DADOS:'
           DISPLAY '  BANKACCT.DAT  BANKTRAN.DAT'
           DISPLAY '  BANKCUST.DAT  BANKEMPREST.DAT'
           DISPLAY '  BANKCART.DAT  BANKAGEND.DAT'
           DISPLAY '  BANKBOL.DAT'
           DISPLAY ''
           DISPLAY ' Desenvolvido com GnuCOBOL + Python'
           DISPLAY ' Arquitetura: MVC em Camadas ISAM'
           DISPLAY '========================================'
           MOVE 0 TO LS-CODIGO.
