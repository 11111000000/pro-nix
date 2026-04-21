<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# Устройство pro-nix — обзор и анализ

Цель документа: кратко и проверяемо описать устройство репозитория pro-nix, важнейшие подсистемы, их роли, текущие сильные стороны и риски, а также практические рекомендации и следующие шаги.

1. Общее назначение
 - Репозиторий предоставляет переносимую конфигурацию NixOS и переносимый Emacs-слой с фокусом на reproducibility, безопасность (peer-сеть) и agent‑workflow.
 - Явный «surface» контракта описан в SURFACE.md: установка из репо, машина‑специфические оверрайды, headless Emacs verification и централизованная поверхность keybindings (emacs-keys.org).

2. Структура репозитория (ключевые части)
 - Nix конфигурация
   - `configuration.nix`, `hardware-configuration.nix`, `local.nix.example` — системный конфиг и примеры per-host overrides.
   - `nix/provided-packages.nix`, `system-packages.nix` (упоминается в SURFACE) — набор системных пакетов и агент‑CLI доступных в PATH.

 - Emacs layer
   - `emacs/base/` — переносимый Emacs loader (`init.el`, `site-init.el`, `early-init.el`) и модульная организация `emacs/base/modules/*.el` (git, org, nix, ui, ai и т.д.).
   - `emacs-keys.org` — единая поверхность глобальных keybindings; пользовательские переопределения через `~/.emacs.d/keys.org`.
   - Headless verification: скрипты и ERT тесты (`scripts/emacs-headless-test.sh`, `scripts/test-emacs-headless.sh`, `test/ert/`).

 - Peer / pro-peer features
   - Скрипты: `scripts/pro-peer-sync-keys.sh`, `scripts/pro-peer-acceptor.sh`, `scripts/backup-hiddenservice.sh` и др.; docs: `docs/analyse/pro-peer-specs.md`, `docs/analyse/peer-networking-overview.md`.
   - Способ работы: авторизованные ключи хранятся зашифрованными (authorized_keys.gpg), синхронизация через systemd unit/timer; опции доступа через Tor Hidden Service, WireGuard/Headscale, Yggdrasil.

 - Agent tooling и CLI
   - `system-packages.nix` обеспечивает наличие `goose`, `aider`, `opencode` на PATH; docs/планы описывают политику и lazy bootstrap поведения (docs/analyse/agent-tooling-dialectical-analysis.md).

 - Сценарии установки и bootstrap
   - `bootstrap/install.sh`, `bootstrap/install-pro.sh`, `bootstrap/choose-host.sh` — интерактивные потоки установки.

 - Утилиты и вспомогательные скрипты
   - Мониторинг/логи: `scripts/parse-emacs-logs.sh`, `scripts/monitor-emacs-logs.sh`, `scripts/emacs-headless-report.sh`.
   - Разные helper‑скрипты для обмена Nix-артефактами, тестов и CI (см. `scripts/`).

3. Сильные стороны
 - Чётко описанный public contract (SURFACE.md) и HDS правила для поддержки качества кода и структуры.
 - Модульная организация Emacs-слоя: отдельные .el по concern, прозрачный loader и headless verification pipeline.
 - Продуманная модель peer-сети: GPG-зашифрованный источник truth для authorized_keys, forced‑command acceptor, использование Tor/Yggdrasil/WG как опций.
 - Наличие тестов (ERT), CI-конфигурации (`.github/workflows/emacs-headless.yml`) и утилит для сбора логов и отчетов.

4. Риски и пробелы
 - Некоторая документация ссылается на артефакты (`flake.nix`, `system-packages.nix`), которые могут отсутствовать или отличаться в рабочем дереве — синхронизация текста и реализации должна поддерживаться.
 - Автоматизация с GPG: текущая политика запрещает автоматическое использование приватного GPG ключа в CI; при этом операторы могут ошибиться при ручной ротации — иметь playbook/скрипты важно.
 - Agent‑CLI в PATH может быть доступен, но иметь lazy bootstrap/backends — это стоит явно тестировать на CI и документировать UX (см. agent-tooling doc).
 - Отсутствие единого, проверяемого matrix-а для headless Emacs (версии, envs): есть тесты, но полезно формализовать matrix в docs/plans и CI.

5. Практические рекомендации (быстрые, приоритеты)
 1. Проверить соответствие упоминаний в SURFACE.md и файлам в репо (например flake.nix). Если упоминание неактуально — отметить или удалить.
 2. Добавить небольшой playbook/Makefile/script для безопасной ротации GPG → `scripts/rotate-authorized-keys.sh` (операторный, non-automatic) и документировать шаги в docs/plans.
 3. В CI добавить smoke test, который проверяет, что `goose`, `aider`, `opencode` запускаются с ожидаемым return code и сообщением о lazy‑bootstrap (чтобы обнаружить runtime surprises).
 4. Формализовать headless Emacs matrix (Emacs версии, TTY vs Xorg, minimal deps) и включить в `.github/workflows/emacs-headless.yml` параметры для стабильной репликации.
 5. Для pro-peer acceptor: добавить unit tests/integration test, которые симулируют forced‑command и проверяют логирование и ограничения.

6. Короткий чек‑лист для ревью/внедрения
 - [ ] SURFACE.md references are accurate (files exist and match promises)
 - [ ] `authorized_keys.gpg` workflow documented with operator script for rotate/revoke
 - [ ] Headless Emacs matrix established in CI
 - [ ] Agent CLI runtime behavior smoke test in CI
 - [ ] pro-peer forced‑command has integration test and logrotate policy

7. Где смотреть в репо
 - SURFACE.md, AGENTS.md, README.md
 - `emacs/base/` (модульная Emacs база)
 - `scripts/` (peer, headless, sync, report)
 - `docs/plans/` и `docs/analyse/` (существующие планы и анализы — хорошая точка входа)

Заключение
 - Репозиторий организован последовательно: явный public contract, модульный Emacs-слой и продуманный pro-peer дизайн. Рекомендуемые действия сосредоточены на синхронизации документации с реализацией, автоматизированных smoke‑тестах для agent‑cli и безопасных operator‑скриптах для GPG/ключей.

Если хотите, следующие шаги могу выполнить автоматически: 1) добавить playbook для ротации ключей, 2) создать CI smoke тест для agent‑CLI, или 3) добавить интеграционный тест для pro‑peer acceptor — скажите, что предпочитаете первым.
