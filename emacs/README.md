# pro-nix Emacs configuration — Документация

Коротко: конфигурация Emacs в этом репозитории теперь организована единообразно — все системные модули находятся в `emacs/base/modules/` и называются с префиксом `pro-` (файлы `pro-<name>.el`). Каждый модуль предоставляет feature с тем же именем: `(provide 'pro-<name>)`.

Цели миграции
- Единообразие имён (все системные модули — `pro-...`).
- Легкая обнаруживаемость и безопасная загрузка модулей.
- Документированность: модули снабжены русскоязычными literate заголовками и докстрингами.

Краткие инструкции

- Локально запустить проверку изолированной загрузки всех модулей:

  ```sh
  ./scripts/smoke-load-modules.sh
  ```

  Скрипт выполняет `emacs --batch -Q -l` для каждого модуля (изолированно) и сообщает об ошибках.

- Запустить ERT smoke-тест (тест пытается загрузить все модули в контексте init):

  ```sh
  PRO_PACKAGES_AUTO_INSTALL=0 emacs --batch -l emacs/base/init.el -l emacs/base/tests/test-smoke-pro-modules.el -f ert-run-tests-batch-and-exit
  ```

Политика совместимости
- Миграция сделана «вжёсткую» (без shim'ов). Пользовательские локальные overrides, которые ссылались на старые имена модулей, должны быть обновлены на `pro-`-версии.

Где смотреть
- Модули: `emacs/base/modules/` — все модули `pro-*.el`.
- Тесты: `emacs/base/tests/test-smoke-pro-modules.el`.
- Скрипты: `scripts/rename-modules-pro.sh`, `scripts/patch-pro-provides.sh`, `scripts/smoke-load-modules.sh`.

Если у вас есть локальные `~/.config/emacs/modules/` или `~/.config/emacs/keys.org`, проверьте и обновите имена модулей и ссылки на функции.
