# Emacs headless changelog

## v2026-04-20

### Что нового

- Добавлен headless-тестер с временным HOME: `scripts/test-emacs-headless.sh`.
- Добавлен парсер логов: `scripts/parse-emacs-logs.sh`.
- Добавлены ERT-тесты для базовой загрузки Emacs и модулей: `emacs/base/modules/tests.el`.
- Добавлены хелперы headless-тестов: `emacs/base/modules/test-helpers.el`.
- Интеграция в `just`: `headless-tests`, `headless-parse`.
- Обновление `.gitignore`: `*.elc`, `*.eln`, `*#`, `.#*`, `*.bak`, `*.orig`, `*.rej`, `auto-save-list/`.

### Что изменилось

- `scripts/test-emacs-headless.sh`: batch-ERT в TTY и Xorg (Xvfb).
- `scripts/parse-emacs-logs.sh`: парсинг последнего или указанного прогона.
- `scripts/emacs-headless-report.sh`: добавлена сводка по логам.
- `emacs/base/site-init.el`: minimal cleanups.
- `emacs/base/modules/ui.el`: reduced duplicate logic, moved to core.
- `justfile`: добавлены цели для headless-проверки.

### Тесты

- `./scripts/test-emacs-headless.sh tty`
- `./scripts/test-emacs-headless.sh xorg`
- `./scripts/test-emacs-headless.sh both`

### Парсер логов

- `./scripts/parse-emacs-logs.sh`
- `just headless-parse`

### Заметки

- Тесты работают с временным HOME и не зависят от живого `~/.emacs.d`.
- Логи пишутся в `logs/emacs-tests/<timestamp>/`.
