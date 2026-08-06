
COBC     = cobc
COBFLAGS = -Wall -I .
BINDIR   = bin
COB_CFLAGS_SAFE = -finline-functions -ggdb3 -pipe -Wdate-time -Wno-unused -fsigned-char -Wno-pointer-sign -D_FORTIFY_SOURCE=3
COBENV   = env CFLAGS= CPPFLAGS= COB_CFLAGS="$(COB_CFLAGS_SAFE)"

.PHONY: all clean install run run-gui acceptance acceptance-fast acceptance-finance test test-fast export-deps core-deps core-test core-init bankexport core-migrate core-bridge-test

all: dirs bankacct banktran bankinv bankrep bankqry banktrf bankpay bankcrm bankadm bankloan bankcard bankschd bankauth bankhelp bankfx bankseg bankcons bankprev bankdeb bankcap banklim banknotif banktax bankchq bankfgts bankcob bankovd bankpoup bankconsig bankscore bankcashback bankreneg bankport bankpj bankdoa bankmain bankexport

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

bankloan:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKLOAN.cob -o $(BINDIR)/BANKLOAN.so

bankcard:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKCARD.cob -o $(BINDIR)/BANKCARD.so

bankschd:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKSCHD.cob -o $(BINDIR)/BANKSCHD.so

bankauth:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKAUTH.cob -o $(BINDIR)/BANKAUTH.so

bankhelp:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKHELP.cob -o $(BINDIR)/BANKHELP.so

bankfx:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKFX.cob -o $(BINDIR)/BANKFX.so

bankseg:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKSEG.cob -o $(BINDIR)/BANKSEG.so

bankcons:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKCONS.cob -o $(BINDIR)/BANKCONS.so

bankprev:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKPREV.cob -o $(BINDIR)/BANKPREV.so

bankdeb:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKDEB.cob -o $(BINDIR)/BANKDEB.so

bankcap:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKCAP.cob -o $(BINDIR)/BANKCAP.so

banklim:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKLIM.cob -o $(BINDIR)/BANKLIM.so

banknotif:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKNOTIF.cob -o $(BINDIR)/BANKNOTIF.so

banktax:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKTAX.cob -o $(BINDIR)/BANKTAX.so

bankchq:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKCHQ.cob -o $(BINDIR)/BANKCHQ.so

bankfgts:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKFGTS.cob -o $(BINDIR)/BANKFGTS.so

bankcob:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKCOB.cob -o $(BINDIR)/BANKCOB.so

bankovd:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKOVD.cob -o $(BINDIR)/BANKOVD.so

bankpoup:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKPOUP.cob -o $(BINDIR)/BANKPOUP.so

bankconsig:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKCONSIG.cob -o $(BINDIR)/BANKCONSIG.so

bankscore:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKSCORE.cob -o $(BINDIR)/BANKSCORE.so

bankcashback:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKCASHBACK.cob -o $(BINDIR)/BANKCASHBACK.so

bankreneg:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKRENEG.cob -o $(BINDIR)/BANKRENEG.so

bankport:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKPORT.cob -o $(BINDIR)/BANKPORT.so

bankpj:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKPJ.cob -o $(BINDIR)/BANKPJ.so

bankdoa:
	$(COBENV) $(COBC) -m $(COBFLAGS) \
		BANKDOA.cob -o $(BINDIR)/BANKDOA.so

bankmain: bankacct banktran bankinv bankrep bankqry banktrf bankpay bankcrm bankadm bankloan bankcard bankschd bankauth bankhelp bankfx bankseg bankcons bankprev bankdeb bankcap banklim banknotif banktax bankchq bankfgts bankcob bankovd bankpoup bankconsig bankscore bankcashback bankreneg bankport bankpj bankdoa
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
		$(BINDIR)/BANKLOAN.so \
		$(BINDIR)/BANKCARD.so \
		$(BINDIR)/BANKSCHD.so \
		$(BINDIR)/BANKAUTH.so \
		$(BINDIR)/BANKHELP.so \
		$(BINDIR)/BANKFX.so \
		$(BINDIR)/BANKSEG.so \
		$(BINDIR)/BANKCONS.so \
		$(BINDIR)/BANKPREV.so \
		$(BINDIR)/BANKDEB.so \
		$(BINDIR)/BANKCAP.so \
		$(BINDIR)/BANKLIM.so \
		$(BINDIR)/BANKNOTIF.so \
		$(BINDIR)/BANKTAX.so \
		$(BINDIR)/BANKCHQ.so \
		$(BINDIR)/BANKFGTS.so \
		$(BINDIR)/BANKCOB.so \
		$(BINDIR)/BANKOVD.so \
		$(BINDIR)/BANKPOUP.so \
		$(BINDIR)/BANKCONSIG.so \
		$(BINDIR)/BANKSCORE.so \
		$(BINDIR)/BANKCASHBACK.so \
		$(BINDIR)/BANKRENEG.so \
		$(BINDIR)/BANKPORT.so \
		$(BINDIR)/BANKPJ.so \
		$(BINDIR)/BANKDOA.so \
		-o $(BINDIR)/bankmain

clean:
	rm -rf $(BINDIR)
	rm -f *.DAT *.DAT.* *.LOG *.LOG.* *.TXT *.idx *.dat

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

test: bankmain
	python3 test_suite.py

test-fast:
	python3 test_suite.py

export-deps:
	pip3 install openpyxl fpdf2

core-deps:
	python3 -m pip install -r requirements-security.txt

core-test:
	python3 -m pytest -q tests/unit/test_bank_core.py

core-init:
	python3 bank_core_cli.py init

bankexport: dirs
	$(COBENV) $(COBC) -x $(COBFLAGS) \
		BANKEXPORT.cob -o $(BINDIR)/bankexport

core-migrate: bankexport core-init
	./$(BINDIR)/bankexport
	python3 bank_core_cli.py migrate-isam-dump BANKACCT.DUMP

core-bridge-test:
	python3 -m pytest -q tests/unit/test_bank_core_cli_bridge.py
