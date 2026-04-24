# pro-nix — модульные Nix-конфигурации: рабочая станция, кластер, VPN и Emacs

Кратко
-----
pro-nix — набор взаимосвязанных Nix-модулей, flake-сборок и вспомогательных
скриптов для воспроизводимой конфигурации рабочих станций и серверов. Emacs и
Home Manager — важная, но не единственная часть проекта: здесь собраны
политики, модули и пакеты для рабочего поля, приватных сетей и кластерных
сценариев.

Badges
------
<!-- Добавьте бейджи CI/flake/license при наличии -->

Prerequisites
-------------
- Nix с поддержкой flakes (рекомендуется современная версия, flake-enabled).
- network access для substitute/cache при сборке.
- root/sudo при применении `nixos-rebuild`/`just switch` на целевой машине.

Quickstart — локальная проверка
------------------------------
1. Клонировать репозиторий

   git clone git@github.com:11111000000/pro-nix.git
   cd pro-nix

2. Прогнать flake checks

   nix flake check

3. Построить конфигурацию хоста (пример)

   nix build .#nixosConfigurations.cf19.config.system.build.toplevel
   nix build .#nixosConfigurations.huawei.config.system.build.toplevel

4. Открыть devshell для разработки

   nix develop .#devShells.x86_64-linux.default

5. Запустить Emacs с локальной конфигурацией (тест)

   emacs -Q -l emacs/base/init.el
   # или
   ./scripts/emacs-pro-wrapper.sh

6. Запустить headless Emacs E2E тесты

   ./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el

Организация репозитория (основные точки входа)
---------------------------------------------
- flake.nix — flake outputs: `nixosConfigurations` (hosts), `apps`, `devShells`, `checks`.
- configuration.nix — общая cross-host политика, импортирует `modules/`.
- system-packages.nix — централизованный список пакетов (с флагом enableOptional).
- modules/ — набор NixOS-модулей (pro-users, pro-services, pro-privacy, pro-peer, headscale и др.).
- nix/modules/ — вспомогательные Nix-модули (samba, automount и др.).
- nixos/modules/ — модули для opencode и связанных компонентов.
- hosts/ — host-specific конфиги (cf19, huawei).
- scripts/ — вспомогательные утилиты и тесты.
- docs/specs/ — формальные спецификации публичных контрактов (join-secret, proctl-spec).

Как тестировать
---------------
- Flake static checks: `nix flake check`.
- Собрать образ/конфигурацию хоста: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`.
- Devshell: `nix develop .#devShells.x86_64-linux.default`.
- Emacs E2E: `./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el`.

Contributing (короткий чек-лист)
--------------------------------
1. Создайте ветку: `git checkout -b feat/<short-desc>`.
2. Следуйте Change Gate (см. AGENTS.md). В PR укажите:
   - Intent: <кратко>
   - Pressure: Bug | Feature | Debt | Ops
   - Surface impact: (none) | touches: <SURFACE item(s)> [FROZEN/FLUID]
   - Proof: tests/commands, инструкции для проверки
3. Локально прогоните `nix flake check` и соответствующие тесты (Emacs E2E, сборка хоста).
4. Откройте PR с инструкцией по проверке.

Change Gate (шаблон для PR)
---------------------------
Intent: <одно предложение>

Pressure: Bug | Feature | Debt | Ops

Surface impact: (none) | touches: <SURFACE item(s)> [FROZEN/FLUID]

Proof: tests: <команда(ы) для воспроизведения>

Где смотреть дальше
-------------------
- AGENTS.md — политика изменений, HDS workflow.
- docs/ — исследования, операционные инструкции и HOLO/SURFACE (если имеются).
- scripts/ — вспомогательные утилиты и тесты.

License
-------
Добавьте файл LICENSE в корень репозитория, если нужно. Если лицензия уже есть — укажите её здесь.

Contacts / Issues
-----------------
Открывайте issues/PR в данном репозитории. Для оперативных/ops вопросов см. `docs/ops/README.md`.
