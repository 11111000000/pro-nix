# pro-nix: воспроизводимая NixOS-платформа

pro-nix — воспроизводимая конфигурация NixOS, Emacs и операционных инструментов. Репозиторий задаёт целостную рабочую систему: базовую ОС, пользовательскую среду, сетевые сервисы, Emacs-платформу, агентные и LLM-инструменты, а также проверки, которые подтверждают поведение системы.

Состояние машины выводится из читаемой, проверяемой и композиционной спецификации. Публичное поведение описывается в SURFACE.md и подтверждается Proof.

## Суть

pro-nix соединяет четыре слоя в один контур:

- NixOS — политика системы: загрузка, сеть, пользователи, сервисы, безопасность, пакеты.
- Emacs — переносимая рабочая платформа: LSP, REPL, EXWM, soft reload.
- Ops — операционные сценарии: peer discovery, Tor, key sync, headscale, storage, resource limits.
- Agents/LLM — воспроизводимые entrypoint-ы для исследований, прототипирования и локальной агентной работы.

Проект функционирует как контрактная система. SURFACE.md фиксирует публичные гарантии. HOLO.md фиксирует инварианты и решения. Код в modules/, hosts/, emacs/, scripts/ и tools/ реализует эти гарантии композиционно.

## Принципы

- Воспроизводимость — основное требование к конфигурации.
- Модуль вносит вклад, не финализируя систему.
- Публичное поведение фиксируется как Surface и подтверждается Proof.
- Секреты хранятся вне git.
- Emacs — часть платформы.
- Агентные и LLM-инструменты следуют правилам воспроизводимости.

## Архитектура

| Область | Файлы | Назначение |
|---------|-------|------------|
| Flake-интерфейс | flake.nix | Единая точка входа: хосты, checks, apps, devshells. |
| Общая NixOS-политика | configuration.nix | Кросс-хостовая база: загрузчик, сеть, пользователи, сервисы, runtime. |
| Хосты | hosts/*/configuration.nix | Host-specific параметры и отличия. |
| Модули NixOS | modules/*.nix, nixos/modules/*.nix | Составные политики: сеть, privacy, peer, desktop, opencode, zram. |
| Пакеты | system-packages.nix, packages-runtime.nix | Базовые утилиты, Emacs runtime, optional-пакеты, LLM entrypoint-ы. |
| Emacs | emacs/home-manager.nix, emacs/base/* | Переносимый профиль Emacs через Home Manager и site-lisp. |
| Скрипты и проверки | scripts/*, tests/*, tools/* | Smoke, ops, contract tests и утилиты верификации. |
| Документация | SURFACE.md, HOLO.md, docs/*, CONTRIBUTING.md | Контракты, решения и процессы изменения. |

## Подсистемы

NixOS

configuration.nix собирает общую политику. hosts/* задают host-specific параметры: загрузчик, разделы, флаг включения сервисов и аппаратные опции.

Emacs

emacs/home-manager.nix и emacs/base/* формируют переносимый профиль: предоставляют emacsRuntime, load-path и набор модулей с поддержкой soft reload.

Peer, сеть и приватность

pro-peer, pro-services, pro-privacy и headscale обеспечивают: NetworkManager, systemd-resolved, SSH hardening, Avahi/mDNS, синхронизацию ключей, Tor client, Tor hidden service, Yggdrasil и WireGuard helper.

Пакеты и runtime

system-packages.nix разделяет базовые и optional-пакеты. enableOptional контролирует включение тяжёлых GUI/сервисов.

Агенты и LLM

llm-lab, opencode и proctl — воспроизводимые entrypoint-ы для исследований и прототипирования. Эти инструменты входят в операционную среду и подчиняются тем же правилам воспроизводимости.

## Хосты

| Хост | Назначение | Особенности |
|------|------------|-------------|
| huawei | Основная laptop/workstation | systemd-boot, zram/opencode limits, рабочий набор сервисов. |
| cf19 | Полевая/операционная конфигурация | GRUB/BIOS, pro-peer key sync, Tor hidden service for SSH. |
| vm | Минимальная виртуальная конфигурация | Быстрая проверка сборки и изоляция экспериментов. |

Сборка хоста:

```bash
nix build .#nixosConfigurations.huawei.config.system.build.toplevel
```

Live-активация выполняется после проверок:

```bash
sudo nixos-rebuild switch --flake .#huawei
```

## Быстрый старт

1. Клонировать репозиторий:

```bash
git clone git@github.com:11111000000/pro-nix.git
cd pro-nix
```

2. Проверить flake:

```bash
nix flake check
```

3. Собрать профиль хоста:

```bash
nix build .#nixosConfigurations.huawei.config.system.build.toplevel
```

4. Войти в devshell:

```bash
nix develop .#devShells.x86_64-linux.default
```

5. Запустить Emacs:

```bash
./scripts/emacs-pro-wrapper.sh
```

6. Запустить проверочный entrypoint:

```bash
nix run .#check-all
```

## Контракты и Proof

Код и публичные обещания разграничены. Изменения публичного поведения фиксируются в SURFACE.md и сопровождаются Proof.

- SURFACE.md — реестр публичных контрактов и команд для их проверки.
- HOLO.md — инварианты и архитектурные решения.
- AGENTS.md — правила взаимодействия агентов и инженерные ограничения.
- CONTRIBUTING.md — процесс изменения: Change Gate, проверки, rollback/canary.

Минимальные проверки:

```bash
./tools/surface-lint.sh
./tools/holo-verify.sh
```

Базовая flake-проверка:

```bash
nix flake check
```

## Рабочий цикл

1. inspect — прочитать AGENTS.md, SURFACE.md, HOLO.md и релевантные модули.
2. contract — определить влияние на публичную поверхность; для FROZEN подготовить Migration и Proof.
3. patch — внести минимальную правку.
4. verify — запустить Proof и релевантные проверки.
5. switch — применять live-конфигурацию после успешных preflight-проверок.

Подробный процесс — в CONTRIBUTING.md.

## Границы репозитория

В репозитории хранится:

- декларативная NixOS и Home Manager политика;
- публичные контракты и решения;
- проверяемые scripts, tools и tests;
- воспроизводимые entrypoint-ы для Emacs, ops и LLM.

В репозитории не хранятся:

- приватные ключи, токены и незашифрованные credentials;
- machine-local state, который нельзя вывести из конфигурации;
- временные артефакты сборки и дампы.

Host-specific секреты и локальные исключения находятся вне публичной истории или в operator-managed encrypted artifacts.

## Карта чтения

1. README.md — обзор и карта проекта.
2. SURFACE.md — публичные гарантии и Proof.
3. HOLO.md — инварианты и решения.
4. CONTRIBUTING.md — процесс изменений.
5. docs/ — детальные спецификации и runbook-и.

## Короткая формула

pro-nix — воспроизводимая рабочая система, где ОС, Emacs, сеть, ops-инструменты, агенты и проверки связаны единым контрактом.
