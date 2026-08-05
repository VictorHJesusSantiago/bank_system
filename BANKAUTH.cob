       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKAUTH.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-COMMAND               PIC X(80)
           VALUE 'python3 bank_security_console.py menu'.

       LINKAGE SECTION.
       01  LS-RETORNO               PIC 9(4).

       PROCEDURE DIVISION USING LS-RETORNO.
       0000-PRINCIPAL.
           MOVE 0 TO LS-RETORNO
           CALL 'SYSTEM' USING WS-COMMAND
           IF RETURN-CODE NOT = 0
               MOVE 5 TO LS-RETORNO
               DISPLAY 'ERRO NO CONSOLE SEGURO DE AUTENTICACAO'
           END-IF
           GOBACK.

       END PROGRAM BANKAUTH.
