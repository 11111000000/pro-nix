SURFACE — реестр публичных контрактов
====================================

Описание
--------
Каждая запись описывает наблюдаемое, проверяемое поведение репозитория и указывает
Proof — конкретную команду или тест, обеспечивающие воспроизводимую проверку этого
поведения. Для записей с пометкой [FROZEN] любые изменения требуют Change Gate
с миграцией и соответствующими Proof.

Записи
------

- Имя: Healthcheck
  Стабильность: [FROZEN]
  Спецификация: минимальная воспроизводимая проверка работоспособности репозитория —
  строится набор проверок, которые должны успешно выполняться в чистой среде.
  Proof: `tests/contract/test_surface_health.spec`
  Owner: `tools/surface-lint.sh`, `tests/contract`

- Имя: Soft Reload (Emacs)
  Стабильность: [FROZEN]
  Спецификация: опция `pro.emacs.softReload.enable` обеспечивает безопасную подгрузку
  UI, ключевых модулей и конфигурации Emacs без полного перезапуска; поведение
  покрывается headless ERT тестами.
  Proof: `./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el`
  Owner: `emacs/base`, `scripts/emacs-*`, `tests/contract`

- Имя: Pro-peer Key Sync
  Стабильность: [FLUID]
  Спецификация: опция `pro-peer.enableKeySync` управляет systemd unit и вспомогательным
  скриптом `scripts/pro-peer-sync-keys.sh` для распространения/получения authorized_keys
  между доверенными хостами.
  Proof: `scripts/pro-peer-sync-keys.sh --help` и `tests/contract/unit/01-pro-peer-basic.sh`
  Owner: `scripts/pro-peer-*.sh`, `modules/pro-peer.nix`

- Имя: LLM Research Surface (llm-lab)
  Стабильность: [FLUID]
  Спецификация: воспроизводимый entrypoint `llm-lab` (Jupyter/точка входа) для
  экспериментов с моделями и инструментами LLM; покрыт unit-скриптом.
  Proof: `tests/contract/unit/03-llm-tools.sh`
  Owner: `apps/`, `tests/contract`

- Имя: Flake Outputs / Host Entrypoints
  Стабильность: [FROZEN]
  Спецификация: flake предоставляет воспроизводимые outputs: `nixosConfigurations`,
  `devShells`, `apps.check-all`. Их наличия и корректность проверяют flake-based
  проверки и CI.
  Proof: `nix flake check`, `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
  Owner: `flake.nix`, `nixos/*`

- Имя: Git Worktree Policy
  Стабильность: [FLUID]
  Спецификация: все агенты (автоматические и люди), вносящие изменения в репозиторий pro-nix,
  обязаны работать в отдельной git worktree, а не в primary worktree. Policy обеспечивает изоляцию рабочих контекстов и предотвращает случайные коммиты в основную операционную директорию.
  Proof: `./scripts/check-worktree.sh --help` и `./scripts/setup-worktree.sh --help` (скрипты проверяют и создают worktree); рекомендуемое preflight: `./scripts/check-worktree.sh`.
  Owner: `AGENTS.md`, `scripts/setup-worktree.sh`, `scripts/check-worktree.sh`

- Имя: Runtime Packages & Activation
  Стабильность: [FLUID]
  Спецификация: набор runtime-пакетов, необходимых для корректной активации системы
  и работы вспомогательных скриптов (activate, ensure-perms, helpers). Документируется
  в `system-packages.nix` и проверяется тестами активации.
  Proof: `tests/contract/test_runtime_packages.sh`, `./scripts/check-nixos-build.sh`
  Owner: `system-packages.nix`, `modules/*`

- Имя: Emacs Runtime State Hygiene
  Стабильность: [FLUID]
  Спецификация: разделение конфигурации, долговечного состояния и кэша для pro-Emacs.
    - Конфигурация: `~/.config/emacs`
    - Долговечное состояние (history, savehist, recentf, places, backups, sessions): `~/.local/state/pro-emacs`
    - Кэш/временные файлы (auto-save, temp, logs): `~/.cache/pro-emacs`
    Модуль `emacs/base/modules/pro-history.el` применяет эти пути и policy для backup/auto-save/savehist/recentf/saveplace.
  Proof: `emacs/base/tests/test-history.el`, `./scripts/test-emacs-headless.sh tty`
  Owner: `emacs/base/modules/pro-history.el`, `emacs/home-manager.nix`

Как пользоваться
---------------
1. Для просмотра всех публичных записей используйте этот файл — SURFACE.md.
2. Перед изменением любой записи с пометкой [FROZEN] оформляйте Change Gate в PR
   (Intent, Pressure, Surface impact, Proof, Migration если необходимо).
