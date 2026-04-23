set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
	@just --list

install:
	./bootstrap/install.sh

install-nixos:
	./bootstrap/install.sh

install-emacs:
	./scripts/emacs-sync.sh

install-plain:
	./scripts/emacs-sync.sh


build HOST:
	sudo nixos-rebuild build --flake .#{{HOST}}




	scripts/switch.sh "{{HOST}}"

test HOST:
	sudo nixos-rebuild test --flake .#{{HOST}}

flake-check:
	nix flake check
check-all:
	nix run .#check-all

headless-tty:
	./scripts/emacs-verify.sh tty

headless-xorg:
	./scripts/emacs-verify.sh xorg

headless:
	./scripts/emacs-verify.sh both

headless-tests:
	./scripts/test-emacs-headless.sh both

headless-parse:
	./scripts/parse-emacs-logs.sh

headless-report:
	./scripts/emacs-headless-report.sh

logs-latest:
	./scripts/emacs-headless-report.sh

emacs-sync:
	./scripts/emacs-sync.sh

emacs-verify:
	./scripts/emacs-verify.sh both
