set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
	@just --list

build:
	sudo nixos-rebuild build --flake .#pro

test:
	sudo nixos-rebuild test --flake .#pro

switch:
	sudo nixos-rebuild switch --flake .#pro

flake-check:
	nix flake check

headless-tty:
	./scripts/pro-emacs-headless-test tty

headless-xorg:
	./scripts/pro-emacs-headless-test xorg

headless:
	./scripts/pro-emacs-headless-test both

headless-report:
	./scripts/pro-emacs-headless-report.sh

logs-latest:
	./scripts/pro-emacs-headless-report.sh
