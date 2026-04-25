SURFACE — реестр публичных контрактов
=====================================

Запись описывает наблюдаемое поведение репозитория и команду(ы) — Proof, которые
это поведение проверяют.

- Имя: Healthcheck
  Стабильность: [FROZEN]
  Спецификация: репозиторий предоставляет воспроизводимую точку проверки работоспособности.
  Proof: `tests/contract/test_surface_health.spec`

- Имя: Soft Reload (Emacs)
  Стабильность: [FROZEN]
  Спецификация: опция `pro.emacs.softReload.enable` позволяет безопасно обновлять UI,
  настройки и модули без полного перезапуска Emacs; наличие headless ERT, проверяющего
  корректность перезагрузки.
  Proof: headless ERT runner (см. HOLO.md)

- Имя: Pro-peer Key Sync
  Стабильность: [FLUID]
  Спецификация: опция `pro-peer.enableKeySync` управляет systemd-сервисом
  `pro-peer-sync-keys` и скриптом `scripts/pro-peer-sync-keys.sh` для синхронизации ключей.
  Proof: `scripts/pro-peer-sync-keys.sh` (smoke) и соответствующие unit-файлы systemd.

- Имя: LLM Research Surface
  Стабильность: [FLUID]
  Спецификация: воспроизводимый entrypoint `llm-lab` для экспериментов и тестов с LLM.
  Proof: `tests/contract/unit/03-llm-tools.sh`
