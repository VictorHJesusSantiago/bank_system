# Sistema Bancário COBOL - Makefile
# Compilação com GnuCOBOL (formato fixo)

COBC     = cobc
COBFLAGS = -Wall -I .
BINDIR   = bin
COB_CFLAGS_SAFE = -finline-functions -ggdb3 -pipe -Wdate-time -Wno-unused -fsigned-char -Wno-pointer-sign -D_FORTIFY_SOURCE=3
COBENV   = env CFLAGS= CPPFLAGS= COB_CFLAGS="$(COB_CFLAGS_SAFE)"

.PHONY: all clean install run run-gui acceptance acceptance-fast acceptance-finance

all: dirs bankacct banktran bankinv bankrep bankqry banktrf bankpay bankcrm bankadm bankmain

dirs:
	mkdir -p $(BINDIR)

bankacct:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKACCT.cob -o $(BINDIR)/BANKACCT.so

banktran:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKTRAN.cob -o $(BINDIR)/BANKTRAN.so

bankinv:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKINV.cob -o $(BINDIR)/BANKINV.so

bankrep:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKREP.cob -o $(BINDIR)/BANKREP.so

bankqry:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKQRY.cob -o $(BINDIR)/BANKQRY.so

banktrf:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKTRF.cob -o $(BINDIR)/BANKTRF.so

bankpay:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKPAY.cob -o $(BINDIR)/BANKPAY.so

bankcrm:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKCRM.cob -o $(BINDIR)/BANKCRM.so

bankadm:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKADM.cob -o $(BINDIR)/BANKADM.so

bankmain: bankacct banktran bankinv bankrep bankqry banktrf bankpay bankcrm bankadm
	$(COBENV) $(COBC) -x $(COBFLAGS) \
		BANKMAIN.cob \
		$(BINDIR)/BANKACCT.so \
		$(BINDIR)/BANKTRAN.so \
		$(BINDIR)/BANKINV.so \
		$(BINDIR)/BANKREP.so \
		$(BINDIR)/BANKQRY.so \
		$(BINDIR)/BANKTRF.so \
		$(BINDIR)/BANKPAY.so \
		$(BINDIR)/BANKCRM.so \
		$(BINDIR)/BANKADM.so \
		-o $(BINDIR)/bankmain

clean:
	rm -rf $(BINDIR)
	rm -f *.DAT *.DAT.* *.LOG *.LOG.* *.TXT

install:
	cp $(BINDIR)/bankmain /usr/local/bin/bankmain
	@echo "Instalado com sucesso!"

run: bankmain
	COB_LIBRARY_PATH=$(BINDIR) ./$(BINDIR)/bankmain

run-gui: bankmain
	@if python3 -c "import tkinter" >/dev/null 2>&1; then \
		python3 bank_gui.py; \
	elif cmd.exe /C "py -3 -c \"import tkinter\"" >/dev/null 2>&1; then \
		WINPWD=$$(wslpath -w "$$(pwd)"); \
		cmd.exe /C "cd /d $$WINPWD && py -3 bank_gui.py"; \
	else \
		echo "tkinter nao encontrado."; \
		echo "No WSL: sudo apt update && sudo apt install -y python3-tk"; \
		exit 1; \
	fi

acceptance: bankmain
	python3 acceptance_regression.py

acceptance-fast:
	python3 acceptance_regression.py

acceptance-finance:
	python3 finance_regression.py
