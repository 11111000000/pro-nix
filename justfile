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




switch HOST='':
	@HOST="{{HOST}}"; \
	if [ -z "$HOST" ]; then \
	  HOST="$(cat /etc/hostname 2>/dev/null || hostname -s 2>/dev/null || true)"; \
	fi; \
	if [ -z "$HOST" ]; then \
	  echo "No local hostname detected. Run: just switch <host> or set the host name with: sudo hostnamectl set-hostname <name>" >&2; \
	  exit 1; \
	fi; \
	if [ ! -f "./hosts/$HOST/configuration.nix" ]; then \
	  echo "Detected hostname '$HOST' but no matching host configuration found in ./hosts/." >&2; \
	  echo "Available hosts:" >&2; \
	  ls -1 hosts || true; \
	  echo "Run: just switch <host> to choose one of the above or add ./hosts/$HOST/configuration.nix" >&2; \
	  exit 1; \
	fi; \
	# Prefer performing a real switch with sudo. In container environments where
	# sudo cannot gain privileges (eg. "no new privileges" flag), fall back to a
	# non-root build of the toplevel derivation for verification purposes.
	if sudo -n true 2>/dev/null; then
		sudo nixos-rebuild switch --flake ".#$HOST"
	else
		echo "[just] sudo unavailable or cannot gain privileges; performing non-root build check (no switch)" >&2
		nix --extra-experimental-features 'nix-command flakes' build --print-out-paths ".#nixosConfigurations.\"$HOST\".config.system.build.toplevel" --no-link
	fi

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
