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

- Имя: Runtime Packages & Activation
  Стабильность: [FLUID]
  Спецификация: набор runtime-пакетов, необходимых для корректной активации системы
  и работы вспомогательных скриптов (activate, ensure-perms, helpers). Документируется
  в `system-packages.nix` и проверяется тестами активации.
  Proof: `tests/contract/test_runtime_packages.sh`, `./scripts/check-nixos-build.sh`
  Owner: `system-packages.nix`, `modules/*`

Как пользоваться
---------------
1. Для просмотра всех публичных записей используйте этот файл — SURFACE.md.
2. Перед изменением любой записи с пометкой [FROZEN] оформляйте Change Gate в PR
   (Intent, Pressure, Surface impact, Proof, Migration если необходимо).
