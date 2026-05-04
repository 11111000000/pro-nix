# pro-nix — воспроизводимая платформа NixOS + Emacs + Ops + Agents

Коротко: pro-nix — это воспроизводимая, проверяемая и композиционная конфигурация
NixOS, переносимого Emacs-профиля и набора операционных инструментов и
entrypoint-ов для агентных/LLM-экспериментов. Проект организован как набор
публичных контрактов (SURFACE.md), инвариантов и решений (HOLO.md) и Proof-скриптов,
которые подтверждают обещанное поведение.

Цель README — дать сжатую, практическую карту репозитория: что это такое,
для кого, из каких подсистем состоит и как быстро начать работу.

Что ответит этот документ:

- Что это и зачем? (одно предложение)
- Из чего состоит репозиторий (архитектурная карта)
- Кто какие роли играет (user/operator/contributor/researcher)
- Как быстро проверить/собрать/запустить (quickstart)
- Как проверяется «истина» проекта (SURFACE/HOLO/Proof)

Принципы

- Воспроизводимость: конфигурация должна быть вычисляема и документируема.
- Минимализм изменений: один Intent — одно изменение/PR.
- Surface First: публичные обещания фиксируются в SURFACE.md перед изменением.
- Проверяемость: для FROZEN-поверхностей Proof обязателен.
- Безопасность: секреты и machine-local state — вне git.

Краткая архитектура

- flake.nix — внешний интерфейс: hosts, apps, checks, devShells.
- configuration.nix — кросс-хостовая база политики NixOS.
- hosts/* — host-specific конфигурации (huawei, cf19, vm).
- modules/*, nixos/modules/* — составные NixOS-модули (network, peer, privacy, desktop, opencode, zram и т.д.).
- emacs/home-manager.nix, emacs/base/* — переносимый Emacs-профиль, site-lisp, soft-reload helpers.
- system-packages.nix / packages-runtime.nix — системные и runtime-пакеты (включая emacsRuntime, llm-lab, opencode).
- scripts/*, tools/*, tests/* — проверочные скрипты, smoke и contract tests, утилиты верификации.
- SURFACE.md / HOLO.md / CONTRIBUTING.md — публичные контракты, инварианты и процесс изменений.

Подсистемы и ответственность

- NixOS: загрузчик, сеть, пользователи, сервисы, приложения, security-hardening.
- Emacs: переносимый runtime, модули, soft-reload, session-serialization.
- Peer & Privacy: avahi/mdns, pro-peer key sync, Tor client/hidden-service, Yggdrasil, WireGuard helper.
- Ops & Runtimes: opencode delivery, headscale, systemd services, resource limits (zram/opencode slice).
- Agents & LLM: llm-lab, proctl, model-client — reproducible entrypoints for experiments.

Хостовая матрица (кратко)

- huawei — primary laptop/workstation; systemd-boot, zram/opencode limits.
- cf19 — field/ops profile; GRUB/BIOS, pro-peer key sync, Tor hidden service for SSH.
- vm — lightweight virtual image used for CI and fast iteration.

Quickstart

1. Клонировать репозиторий и войти в корень проекта:

```bash
git clone git@github.com:11111000000/pro-nix.git
cd pro-nix
```

Перед любой правкой агент обязан перейти в linked worktree:

```bash
./scripts/check-worktree.sh
./scripts/setup-worktree.sh fix/example
cd ../worktree-fix-example
```

2. Быстрая проверка flake и контрактов:

```bash
nix flake check
./tools/surface-lint.sh
```

3. Собрать профиль хоста (пример для huawei):

```bash
nix build .#nixosConfigurations.huawei.config.system.build.toplevel
```

4. Войти в devshell для разработки:

```bash
nix develop .#devShells.x86_64-linux.default
```

5. Запустить portable Emacs (локально):

```bash
./scripts/emacs-pro-wrapper.sh
```

6. Запустить полный набор проверок (entrypoint):

```bash
nix run .#check-all
```

Контракты, Proof и верификация

Проект отделяет код и публичные обещания. Любое поведение, которое необходимо
гарантировать внешним пользователям или другим подсистемам, описано в SURFACE.md
и сопровождается Proof-скриптом или тестом.

- SURFACE.md — публичный реестр контрактов и команды Proof.
- HOLO.md — инварианты, принципы и архитектурные решения.
- CONTRIBUTING.md — порядок изменений: Change Gate, Migration, Proof и Verify.

Основные команды проверки:

```bash
./tools/surface-lint.sh   # проверяет ссылки SURFACE → Proof и базовые style-правила
./tools/holo-verify.sh    # прогон контрактов и вспомогательных проверок
nix flake check           # стандартная flake-проверка
```

Жизненный цикл изменения (сжатая процедура)

1. Inspect — прочитать AGENTS.md, SURFACE.md, HOLO.md и релевантные модули.
2. Contract — сформулировать Intent, Surface impact и Proof (особенно для FROZEN).
3. Patch — минимальный код/док-дифф, соблюдая правила Nix/Emacs проекта.
4. Verify — запустить Proof, surface-lint и holo-verify.
5. Switch — live-активация после успешных preflight-проверок (при необходимости).

Границы репозитория

В репозитории хранится:

- декларативная NixOS/Home-Manager конфигурация;
- проверяемые скрипты и tests/contract;
- документация контрактов (SURFACE.md, HOLO.md) и процесс изменения (CONTRIBUTING.md).

В репозитории НЕ хранится:

- приватные ключи, незашифрованные credentials;
- machine-local state и runtime-артефакты;
- секреты для production — используются внешние operator-managed хранилища (sops/age, vault и т.п.).

Кому это полезно (ролевая карта)

- Пользователь — использует готовую конфигурацию и portable Emacs; читает README + SURFACE.
- Оператор — разворачивает host-specific конфигурации, реагирует на canary и rollback инструкции.
- Контрибьютор — формирует Change Gate, пишет Proof, запускает surface-lint/holo-verify.
- Исследователь/LLM-энтузиаст — использует llm-lab, proctl и devShell для экспериментов.

Карта чтения (рекомендуемая)

1. README.md — обзор и краткая карта.
2. SURFACE.md — публичные контракты и Proof-команды.
3. HOLO.md — инварианты и архитектурные решения.
4. CONTRIBUTING.md — процесс изменения и Change Gate.
5. docs/ — детальные спецификации и runbook-и.

Короткая формула

pro-nix — это не просто NixOS-конфиг: это воспроизводимая рабочая система, в которой
NixOS, Emacs, сеть, операционные инструменты и entrypoint-ы для агентных исследований
связаны единым контрактом и набором проверок.
