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

build:
	sudo nixos-rebuild build --flake .#default

build-huawei:
	sudo nixos-rebuild build --flake .#huawei

test:
	sudo nixos-rebuild test --flake .#default

test-huawei:
	sudo nixos-rebuild test --flake .#huawei

switch:
	sudo nixos-rebuild switch --flake .#default

switch-huawei:
	sudo nixos-rebuild switch --flake .#huawei

flake-check:
	nix flake check

flake-check-huawei:
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
