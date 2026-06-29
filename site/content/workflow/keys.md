+++
title = "Клавиши"
template = "page.html"
weight = 5

[extra]
tldr = "emacs-keys.org — исполняемый код. pro-keys-reload парсит его, применяет глобальные клавиши, откладывает pending-биндинги до загрузки целевого пакета. User override: ~/.config/emacs/keys.org. Модули предлагают через pro/register-module-keys."

[[extra.next]]
title = "Soft-reload"
url = "/workflow/reload/"

[[extra.next]]
title = "Тесты"
url = "/workflow/tests/"
+++

# Клавиши

`emacs-keys.org` — **исполняемый source of truth** для глобальных
клавиш. Это **не** документация. Каждая строка в org-таблице
становит реальный `global-set-key` при старте Emacs. Модули
предлагают новые биндинги через `pro/register-module-keys`;
пользовательские override'ы — в `~/.config/emacs/keys.org`.

## Формат

Файл — это org-mode таблица. Первый столбец — **имя секции**
(используется для группировки биндингов в правильный keymap),
второй — **клавиша**, третий — **команда**, четвёртый — **человеко-читаемое
описание**.

| Секция | Клавиша | Команда | Описание |
|--------|---------|---------|----------|
| Поиск | C-s | isearch-forward | Обычный isearch |
| UI | C-= | pro-ui-zoom-in | Увеличить шрифт |
| EXWM | s-r | exwm-reset | Сброс окна EXWM |

Парсер (`emacs/base/modules/pro-keys.el`) диспатчит по имени
секции:

* `UI` / `EXWM` → `global-set-key` (всегда доступен).
* `ORG` → `org-mode-map` (только когда активен `org-mode`-буфер).
* `Snippets` / `LSP` / `Completion` → `with-eval-after-load` после
  загрузки соответствующей фичи.
* `Suggested` → `pro-keys-pending-bindings` (применяется, когда
  команда пакета становится доступной).

Полная таблица — в [Справочник → Клавиши](reference/keys.md).

## Как работает `pro-keys-reload`

`pro-keys-reload` (интерактивная, без prefix-аргументов):

1. Парсит `emacs-keys.org` (и `~/.config/emacs/keys.org`, если
   есть) как org-таблицы.
2. Для каждой строки — диспатч в правильный keymap.
3. Хранит биндинги, чьи целевые команды ещё не определены, в
   `pro-keys-pending-bindings`.
4. После парсинга запускает `pro-keys-apply-pending`, чтобы
   попробовать отложенные биндинги снова.
5. Печатает сводку: «X биндингов применено, Y в ожидании».

Функция **идемпотентна** — можно вызывать сколько угодно раз,
результат один и тот же набор биндингов.

## Pending-биндинги

Некоторые биндинги ссылаются на команды из пакетов, которые
могут быть не загружены во время парсинга таблицы (например,
`magit-status` из `magit`). Для таких `pro-keys.el` хранит
биндинг в `pro-keys-pending-bindings` и регистрирует
`autoload`-retry:

```elisp
(when (fboundp 'magit-status)
    (define-key global-map (kbd "C-x g") #'magit-status)
  (autoload #'magit-status "magit" nil t)
  (add-hook 'after-load-functions
            (lambda (_)
              (when (fboundp 'magit-status)
                (define-key global-map (kbd "C-x g") #'magit-status)))))
```

`M-x pro-keys-report-pending` печатает список pending-биндингов,
чтобы пользователь мог `M-x package-install` недостающие пакеты.

## Как модули предлагают биндинги

Модули вызывают `pro/register-module-keys`, чтобы **предложить**
биндинг. Предложение хранится в `pro/registered-module-keys` и
мерджится в таблицу `emacs-keys.org` через
`pro/keys-import-suggestions`.

```elisp
(pro/register-module-keys
 "C-c a" 'pro-ai-open-entry "Вход в AI")
```

После загрузки модуля пользователь запускает
`M-x pro/keys-import-suggestions`, который добавляет строку в
`emacs-keys.org` с биндингом в секции `Suggested`. Пользователь
может затем промоутить её в правильную секцию (например, `AI`),
редактируя org-таблицу напрямую.

Это **канонический workflow** для добавления биндинга: модуль
предлагает, пользователь курирует. Ни один модуль не вызывает
`global-set-key` напрямую (линт в `helper-lint-keys.sh` это
обеспечивает).

## Пользовательские override'ы

Пользователь может переопределить системную таблицу, написав
`~/.config/emacs/keys.org` в **том же** формате org-таблицы.
Парсер читает оба файла; если клавиша забиндена в обоих,
**пользовательская** версия выигрывает (last-writer-wins, user
парсится вторым).

Типичный пользовательский override:

```org
#+title: User keys

| Section   | Key         | Command               | Note                       |
|-----------+-------------+-----------------------+----------------------------|
| UI        | C-x M-c     | pro/reload-config     | Reload Emacs config        |
| User      | C-c u       | my-org-capture-tmpl   | Custom capture template    |
```

Имя секции `User` — конвенциональное; парсер не интересуется
именем секции, только столбцами.

## Хук `pro-keys-apply-pending`

После каждого soft-reload (`M-x pro/reload-config`) вызывается
`pro-keys-reload`. Это пере-парсит оба файла и пере-применяет все
биндинги. Механизм pending-биндингов тоже пере-запускается: любой
биндинг, чья целевая команда ещё не доступна, пробуется заново.

Это значит: **отредактируйте `emacs-keys.org`, сохраните, `M-x
pro-keys-reload` (или C-c k)**, и новый биндинг активен. Без
перезапуска Emacs.

## Workflow `pro/keys-import-suggestions`

Если вы добавляете биндинг в модуль через
`(pro/register-module-keys ...)` и хотите влить его в
`emacs-keys.org`:

```elisp
M-x pro/keys-import-suggestions
```

Это:

1. Читает `pro/registered-module-keys` (все предложения от
   загруженных модулей).
2. Дописывает новую секцию `Suggested` в `emacs-keys.org` с одной
   строкой на каждое незарегистрированное предложение.
3. Очищает `pro/registered-module-keys`, так что одно и то же
   предложение не добавляется дважды.

Пользователь затем промоутит строку в правильную секцию,
редактируя org-таблицу.

## Конвенция секции `Suggested`

`emacs-keys.org` имеет секцию `Suggested` внизу. Новые
предложения от модулей идут туда, пока пользователь их не
откурирует. Секция парсится, но клавиши применяются к
`global-map` (поскольку секция не входит в dispatched-имена типа
`UI` / `EXWM`).

## Диспатч секции → keymap

| Секция | Применяется к |
|--------|---------------|
| `UI`, `EXWM` | `global-map` |
| `ORG` | `org-mode-map` (в `with-eval-after-load 'org`) |
| `Snippets`, `LSP`, `Completion` | `with-eval-after-load` для релевантной фичи |
| `History` | `global-map` (команды `pro-history-*`) |
| `Docker` | `global-map` (команды `pro-docker-*`) |
| `AI`, `Чат`, `Tabs`, `Package`, `Git`, `Org`, `Ключи`, `Haskell`, `Profiler` | `global-map` |
| `Suggested` | `global-map` (пользователь должен промоутить) |

Диспатч — в `pro-keys.el:pro-keys--dispatch-section`. Секция
`Suggested` — особенная; это единственная секция, чьи биндинги
применяются даже до пользовательской курации, так что
свежий `pro/register-module-keys`-вызов модуля работает из коробки.

## Линт: нет `global-set-key` в модулях

`scripts/helper-lint-keys.sh` обеспечивает конвенцию:

```bash
rg -n "\bglobal-set-key\s*\(" --glob "**/*.el" \
   | rg -v '/keys\.el:'
```

`rg -v` исключает сам `pro-keys.el` (единственный файл, который
должен вызывать `global-set-key`). Любой другой файл, который это
делает — нарушение.

## Добавление биндинга в существующий модуль

```elisp
;; В вашем pro-foo.el
(pro/register-module-keys
 "C-c f x" 'pro-foo-do-thing "Do the foo thing")
```

Затем `M-x pro/keys-import-suggestions`, чтобы добавить строку в
`emacs-keys.org`. Отредактируйте секцию строки, если хотите её в
`UI` вместо `Suggested`. Сохраните файл. `M-x pro-keys-reload`.
Биндинг активен.

## Добавление нового модульного биндинга

Тот же workflow. Модуль не вызывает `global-set-key` напрямую.
`pro/register-module-keys` — это **предложение**, и
`emacs-keys.org` — **каноническое** место.

Если модуль пытается забиндить клавишу напрямую (например, через
`define-key some-mode-map`), линт поймает это, только если он
вызывает `global-set-key`. Конвенция — класть биндинг в
`emacs-keys.org`, чтобы он отобразился на автогенерированной
странице [Справочник → Клавиши](reference/keys.md).
