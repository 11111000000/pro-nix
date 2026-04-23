# pro-nix — Emacs configuration for reproducible Nix-based setups

Кратко
-----
pro-nix — модульный, воспроизводимый набор конфигураций для Emacs, ориентированный на Nix. Он предоставляет:

- модульную структуру Emacs-конфигов (emacs/base/modules/*.el);
- централизованный реестр глобальных биндов в `emacs-keys.org` и процесс безопасного слияния предложений от модулей;
- инструменты для мягкой перезагрузки модулей и фонового обновления пакетов (MELPA);
- скрипты для подхвата новых `site-lisp` путей из Nix и их применения в работающем Emacs;
- механизм сохранения/восстановления сессии и helper для плавного рестарта при необходимости.

Документы (главное)
-------------------
- HOLO (манифест изменений): `docs/HOLO.md`
- SURFACE (поверхности/контракты): `docs/SURFACE.md`
- План по мягкой перезагрузке и Nix: `docs/plans/soft-reload-and-nix-update.md`
- План терминалов/dired/keys: `docs/plans/emacs-term-dired-harmony.md`

Быстрый старт
-------------
1. Клонируйте репозиторий и откройте его в Nix-окружении (опционально):

   git clone <repo>
   cd pro-nix

2. Локальная проверка headless (E2E):

   ./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el

3. Загрузите Emacs с pro-nix loader (GUI):

   emacs -Q -l emacs/base/init.el

   или используйте wrapper для правильного -L: `./scripts/emacs-pro-wrapper.sh`.

Основные рабочие процессы
-------------------------

1) Обновление Nix-provided elisp путей (после `nix switch`)

   ./scripts/nix-update-emacs-paths.sh
   В Emacs: M-x pro/nix-generate-and-refresh-paths

   Это добавит новые пути в `load-path`. Но: если обновлены C-расширения (.so), нужен рестарт Emacs.

2) Обновление пакетов MELPA в фоне

   В Emacs: M-x pro/update-melpa-in-background
   Или запустить вручную (batch): ./scripts/melpa-update.el

   Логи пишутся в буфер *pro-melpa-update*.

3) Мягкая перезагрузка модулей

   - Перезагрузить конкретный модуль: M-x pro/reload-module RET <module> RET
   - Перезагрузить все модули: M-x pro/reload-all-modules

4) Ключи (Keybindings)

   - Источник истины: `emacs-keys.org` в корне репозитория.
   - Модули публикуют *предложения* через `pro/register-module-keys` (не применяют бинды сразу).
   - Предложения можно собрать и автоматически влить:

     python3 scripts/generate-key-suggestions.py $(pwd) /tmp/emacs-keys-scan.org
     python3 scripts/apply-key-suggestions.py /tmp/emacs-keys-scan.org $(pwd)

   - Перезагрузить бинды: M-x pro/keys-reload

5) Сохранение сессии и плавный рестарт

   - Сохранить сессию: M-x pro/session-save
   - Восстановить: M-x pro/session-restore
   - Сохранить и рестартнуть с восстановлением: M-x pro/session-save-and-restart-emacs

   Ограничение: восстановление терминалов / нативных процессов не полностью автоматизировано.

Проверки и отладка
------------------
- Просмотреть сообщения при загрузке: буфер *Messages*.
- Логи CI/E2E: `.github/workflows/emacs-e2e.yml` и локальный runner `scripts/emacs-pro-wrapper.sh`.
- Если native модуль (vterm/libvterm) не работает после `nix switch`, выполните session save & restart.

Политики и советы
------------------
- Модули не должны назначать глобальные бинды напрямую; используйте `pro/register-module-keys`.
- GUI-фичи guard-ованы `display-graphic-p`.
- Всегда делайте backup перед авто-merge (скрипты создают backup emacs-keys.org.bak.TIMESTAMP).

Где смотреть код
-----------------
- модули: `emacs/base/modules/*.el`
- утилиты: `scripts/*.sh`, `scripts/*.py`, `scripts/*.el`
- документация: `docs/` (HOLO.md, SURFACE.md, plans...)

Контакты и развитие
-------------------
Пожалуйста, открывайте issues/PR для предложений. Цель — поддерживать pro-nix компактным, безопасным и удобным для многомашинного воспроизведения.
