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
- Современный Nix с поддержкой flakes (flake-enabled). Если вы не уверены — обновите Nix и включите flakes.
- Доступ в сеть для substitute/cache при сборке (cache.nixos.org и зеркала).
- root/sudo при применении `nixos-rebuild` / `just switch` на целевой машине.

Quickstart — локальная проверка
------------------------------
1. Клонировать репозиторий

   git clone git@github.com:11111000000/pro-nix.git
   cd pro-nix

2. Прогнать flake checks

   nix flake check

   Если проверка падает — добавьте `--show-trace` для подробной трассировки.

3. Построить конфигурацию хоста (пример)

   # Собрать артефакт для локального просмотра
   nix build .#nixosConfigurations.cf19.config.system.build.toplevel

   # Полный пример: собрать и переключиться на конфигурацию (на целевой машине)
   sudo nixos-rebuild switch --flake .#huawei

   Примечание: flake предоставляет `nixosConfigurations.<host>` — в большинстве сценариев
   `nixos-rebuild --flake .#<host>` является наиболее удобным способом применить конфигурацию на соответствующем хосте.

4. Открыть devshell для разработки

   nix develop .#devShells.x86_64-linux.default

   После входа devshell автоматически создаёт небольшой wrapper для запускa Emacs с нужными флагами
   (файл создаётся в `./.pro-emacs-wrapper/emacs-pro`), см. flake.nix: devShells.shellHook.

5. Запустить Emacs с локальной конфигурацией (тест)

   emacs -Q -l emacs/base/init.el
   # или (обёртка с окружением / путями, рекомендуемый способ для интеграции с Nix)
   ./scripts/emacs-pro-wrapper.sh

6. Запустить headless Emacs E2E тесты

   ./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el

Организация репозитория (основные точки входа)
---------------------------------------------
- flake.nix — flake outputs: `nixosConfigurations` (hosts), `apps`, `devShells`, `checks`.
- configuration.nix — общая cross-host политика, импортирует `modules/`.
- system-packages.nix — централизованный список пакетов (принимает `enableOptional` — смотрите комментарии в файле).
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

Полезные альтернативы
- Быстрая сборка всех хостов (см. flake apps): `nix run .#check-all` или `nix run .#apps.x86_64-linux.check-all`.

Как включить optional-пакеты
---------------------------
`system-packages.nix` содержит группу тяжёлых / опциональных пакетов, контролируемых параметром `enableOptional`.
По умолчанию в `configuration.nix` он импортируется с `enableOptional = false`.
Чтобы включить опциональные пакеты на уровне хоста, добавьте в `hosts/<your-host>/configuration.nix` переопределение:

```nix
environment.systemPackages = lib.mkDefault (with pkgs;
  (config.environment.systemPackages or []) ++ (import ../system-packages.nix { inherit pkgs emacsPkg; enableOptional = true; })
);
```

Это позволит включать большие GUI/игровые пакеты только на тех хостах, где это нужно.

Troubleshooting (частые ошибки)
------------------------------
- Git tree is dirty: flake может смотреть рабочее дерево. Если видите ошибку — закоммитьте/stash изменения.
  `git status --short` / `git add -A && git commit -m "wip"` или `git stash`.
- Дублирование `environment.systemPackages`: используйте `rg "environment.systemPackages" -n` чтобы найти повторные определения — устраните конфликты или используйте `lib.mkForce`/`lib.mkDefault` аккуратно.
- Если `nix` выдаёт непонятную ошибку — повторите с `--show-trace`.

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
