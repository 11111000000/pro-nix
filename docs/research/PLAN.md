<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# -*- fill-column: 88 -*-
#Local Variables:
#coding: utf-8
#End:

* План поиска: Современные техники Emacs Lisp для Emacs 30.2+

Этот документ описывает план поиска и анализа современных техник
организации Emacs Lisp кода.

** Вопросы исследования

1. Какие практики lexical-binding используются?
2. Как организованы модули и зависимости?
3. Какие паттерны загрузки пакетов применяются?
4. Используются ли современные макросы (cl-lib)?
5. Какие паттерны отложенной загрузки?
6. Как организованы настройки (defgroup/defcustom)?
7. Какие современные пакеты уже включены?

** Ключевые техники для Emacs 30.2+

** 1. Lexical Binding

Все файлы должны иметь:
```elisp
;;; file.el --- description -*- lexical-binding: t -*-
```

Должен быть включен в early-init.el для оптимизации загрузки.

** 2. cl-lib для макросов

Современные макросы:
- cl-defun - function definition with keyword args
- cl-labels - local recursive functions
- cl-macrolet - local macros
- cl-flet - local function aliases
- cl-typecase/cl-case - type-based dispatch
- cl-loop - powerful loop macro

** 3. Минимализм

- Один модуль = один файл
- Явные provide/require
- Минимум глобальных переменных
- Использование buffer-local для state

** 4. Производительность

- comp-deferred-compilation для компиляции
- delay-load для тяжелых пакетов
- with-eval-after-load для late binding
- minimize eval-after-load

** 5. Современные пакеты (GNU ELPA)

- vertico - completion backend
- orderless - pattern matching
- marginalia - annotations
- consult - interactive commands
- corfu - in-buffer completion
- xref + consult-xref - reference lookup
- eldoc-box - documentation display

** 6. Новые функции Emacs 30

- improved xref integration
- newcomment-29+ improvements
- subword-mode improvements
- eldoc-documentation-strategy
- compiler notes and warnings

** Скрипты анализа

Скрипты находятся в: docs/research/scripts/

Запуск всех анализов:
```bash
bash docs/research/scripts/run-all-analyses.sh
```

Отдельные анализы:
```bash
bash docs/research/scripts/check-lexical-binding.sh
bash docs/research/scripts/analyze-packages.sh
bash docs/research/scripts/analyze-settings.sh
bash docs/research/scripts/analyze-functions.sh
bash docs/research/scripts/analyze-modules.sh
bash docs/research/scripts/analyze-delayed-load.sh
bash docs/research/scripts/search-modern-features.sh
```

** Результаты

Результаты анализа сохранены в:
- docs/research/analysis-results.org - подробный анализ
- docs/research/analysis-results.txt - сырой вывод скриптов

** Обновление плана

План обновляется по мере выявления новых техник и практик.
