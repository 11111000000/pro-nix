Dired в pro-nix

Кратко: лёгкий модуль dired с удобными клавишами и wdired; GUI-иконки подключаются опционально через `treemacs-icons-dired`.

Что включено
- Клавиши: j/k/l/f/o/RET для открытия, h/^ для подъёма на уровень.
- Режимы: `dired-hide-details-mode`, `hl-line-mode`.
- Настройки: `dired-listing-switches = "-aBhlv --group-directories-first"`, `dired-dwim-target` и автоперенагрузка.
- Wdired: `C-c C-c` — редактирование, `C-c r`/`C-c C-r` для замены.

GUI vs TTY
- Иконки и другие визуальные украшения загружаются только если `display-graphic-p` и пакет доступен.

Проверка
- Headless: `emacs --batch -l emacs/base/init.el -f ert-run-tests-batch` (добавлены тесты для модуля).
