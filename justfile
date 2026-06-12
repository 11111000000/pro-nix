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
	./scripts/deploy-agent-configs.sh \
	  && ./scripts/install-pi-packages.sh \
	  && scripts/switch.sh "{{HOST}}"

# Install npm-extension packages declared in local-templates/pi/settings.json.
# Idempotent. Run after deploy-agent-configs.sh on a fresh machine.
install-pi-packages:
	./scripts/install-pi-packages.sh

# Re-deploy agent configs (templates + npm packages) without re-running nixos-rebuild.
# Useful when only the agent-config templates changed.
deploy-agents:
	./scripts/deploy-agent-configs.sh && ./scripts/install-pi-packages.sh

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

# Contract test for the network layer (pro-hosts, pro-network, pro-ssh-clients, headscale)
network-contract:
	./tests/contract/pro-network-01.sh

# ─── Docker / microservices dev helpers ────────────────────────────────────
# Алиасы для lazydocker / docker CLI. Полезны агентам и человеку, чтобы
# не печатать длинные команды. Все рецепты идемпотентны и не требуют sudo
# (пользователь должен быть в группе `docker`, что делает pro-users.nix).

# TUI: lazydocker — ps/logs/exec/restart/prune в одном интерфейсе
d:
	lazydocker

# Хвост логов контейнера (использует `docker logs -f --tail 100`).
# Использование: just dl <container>
dl NAME:
	docker logs -f --tail 100 {{NAME}}

# Shell в контейнере. По умолчанию /bin/sh; передать другой через CMD.
# Использование: just dsh <container> [cmd]
dsh NAME CMD="sh":
	docker exec -it {{NAME}} {{CMD}}

# Перезапустить контейнер и показать первые 30 строк лога после рестарта.
# Использование: just dr <container>
dr NAME:
	docker restart {{NAME}} && sleep 1 && docker logs --tail 30 {{NAME}}

# Удалить остановленные контейнеры, висячие образы и неиспользуемые сети.
# Без -f сначала спросит подтверждение; здесь -f для неинтерактивного CI/агента.
dprune:
	docker system prune -f
	docker image prune -f
	docker network prune -f

# Сканировать образ на уязвимости через trivy. Только HIGH/CRITICAL по дефолту.
# Использование: just dscan <image> [severity]
dscan IMAGE SEVERITY="HIGH,CRITICAL":
	trivy image --severity {{SEVERITY}} --no-progress {{IMAGE}}

# Статический анализ Dockerfile через hadolint.
# Использование: just dlint <path>
dlint DOCKERFILE="Dockerfile":
	hadolint {{DOCKERFILE}}

# Запустить compose-стек в текущей директории (предполагается compose.yaml).
# Сеть pro-dev подключается автоматически шаблоном templates/microservice/.
dup:
	docker compose up -d

# Остановить compose-стек (контейнеры остаются, можно `docker compose start`).
ddown:
	docker compose down

# Список сервисов текущего compose-проекта с их статусом.
dps:
	docker compose ps

# Хвост логов compose-проекта (все сервисы сразу).
dclogs:
	docker compose logs -f --tail 50
