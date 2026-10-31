.PHONY: install test uninstall help

help:
	@echo "make install    instala o comando cbrasil"
	@echo "make test       roda os testes automatizados"
	@echo "make uninstall  remove o comando e a instalação"

install:
	sh ./install.sh

test:
	sh ./tests/test.sh

uninstall:
	sh ./uninstall.sh
