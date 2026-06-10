set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
	@just --list

install:
	./bootstrap/install.sh

install-nixos:
	./bootstrap/install.sh

install-emacs:
	./scripts/dev-emacs-sync.sh

install-plain:
	./scripts/dev-emacs-sync.sh

build HOST:
	# `git+file://...?submodules=1` нужен чтобы emacs-recipes видели submodules
	# (см. flake-check ниже). `path:` и `.` НЕ включают submodules в captured source.
	sudo nixos-rebuild build --flake "git+file://$(pwd)?submodules=1#{{HOST}}"

switch HOST='':
	scripts/switch.sh "{{HOST}}"

# Deploy local agent configs (pi/opencode) if missing before switch
switch-with-agents HOST='':
	./scripts/deploy-agent-configs.sh && scripts/switch.sh "{{HOST}}"

test HOST:
	sudo nixos-rebuild test --flake "git+file://$(pwd)?submodules=1#{{HOST}}"

flake-check:
	# Используем git+file://...?submodules=1 чтобы submodules попали в nix-store
	# source. `path:` и `.` НЕ включают submodules в captured source, что ломает
	# emacs-recipes, читающие `../../submodules/<name>`.
	nix flake check "git+file://$(pwd)?submodules=1"
check-fast:
	./tools/holo-verify.sh --help >/dev/null

check-docs:
	./tools/holo-verify.sh --help >/dev/null

check-elisp:
	./tools/holo-verify.sh elisp

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
	./scripts/dev-emacs-sync.sh

submodules-ssh:
	scripts/submodules-ssh.sh

emacs-verify:
	./scripts/emacs-verify.sh both
