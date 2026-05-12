Change Gate: Fix Emacs UI module loading and add headless UI tests

Intent: Исправить загрузку и структуру модулей pro-ui (замена устаревших ui-* на pro-ui-*, удаление дубликатов реализаций, добавить headless ERT для обнаружения дубликатов provide и clipboard helper), чтобы восстановить детерминированную загрузку Emacs UI в headless и графических режимах.

Pressure: Bug

Surface impact: Влияет на Emacs Soft Reload surface (Soft Reload (Emacs) — [FROZEN]) — меняется реализация внутренних модулей и добавляются тесты Proof. Поведение public API (фичи pro-ui-*) сохраняется или уточняется; никакой внешней миграции не требуется от пользователей.

Proof:
- Локальные команды для проверки изменений:
  - `PRO_PACKAGES_AUTO_INSTALL=0 emacs --batch -l emacs/base/tests/test-ui-duplicates.el -l emacs/base/tests/test-ui.el -l emacs/base/tests/test-pro-clipboard.el -f ert-run-tests-batch-and-exit`
  - `./scripts/test-emacs-headless.sh tty` (с `PRO_PACKAGES_AUTO_INSTALL=0` в CI)
  - `./tools/surface-lint.sh && ./tools/holo-verify.sh --quick`

Migration: Нет необходимых миграционных шагов; тесты и предложения ключей добавлены опционально. Если пользователи создавали кастомные require 'ui-*' — им следует заменить их на 'pro-ui-*' (documented in emacs/README.md).

Files changed:
- emacs/base/modules/pro-ui.el (refactor: removal of legacy loads, moved helpers, ensure provide at EOF)
- emacs/base/modules/pro-ui-fonts.el (uses shared helpers)
- emacs/base/modules/pro-ui-completion.el (uses shared helpers)
- emacs/base/modules/pro-ui-theme.el (uses shared helpers)
- emacs/base/modules/pro-clipboard.el (new adapter, pro/clipboard-yank-pop)
- emacs/base/early-init.el, emacs/base/init.el, emacs/base/site-init.el (updated requires)
- emacs/base/tests/test-ui-duplicates.el, emacs/base/tests/test-pro-clipboard.el (new tests)
- emacs-keys.org (added suggested entry for C-x y)

Verification steps performed:
- Ran headless ERT with `PRO_PACKAGES_AUTO_INSTALL=0` locally; relevant tests passed (test-ui-duplicates, test-ui, test-pro-clipboard).
- Ensured `emacs --batch -Q` manual loads of modified files succeed.

Notes:
- Because Soft Reload is FROZEN, we include Proof commands and test coverage. No user migration required.
