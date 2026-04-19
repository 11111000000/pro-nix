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

switch HOST:
	sudo nixos-rebuild switch --flake .#{{HOST}}

test HOST:
	sudo nixos-rebuild test --flake .#{{HOST}}

flake-check:
	nix flake check

check-all:
	nix run .#check-all

check-huawei:
	nix build .#nixosConfigurations.huawei.config.system.build.toplevel --no-link

headless-tty:
	./scripts/emacs-verify.sh tty

headless-xorg:
	./scripts/emacs-verify.sh xorg

headless:
	./scripts/emacs-verify.sh both

headless-report:
	./scripts/emacs-headless-report.sh

logs-latest:
	./scripts/emacs-headless-report.sh

emacs-sync:
	./scripts/emacs-sync.sh

emacs-verify:
	./scripts/emacs-verify.sh both