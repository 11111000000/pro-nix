+++
title = "Загрузка Emacs"
template = "page.html"
weight = 4

[extra]
tldr = "Четыре фазы: early-init → init → site-init (манифест + резолвер) → pro-emacs-base-start. Контракт soft-reload позволяет модулям владеть persistent state. provided-packages.el приходит из Nix."

[[extra.next]]
title = "Стек AI-агентов"
url = "/architecture/agents/"

[[extra.next]]
title = "Справочник defcustom"
url = "/reference/defcustom/"
+++

# Загрузка Emacs

Сторона Emacs имеет свой четырёхфазный bootstrap, намеренно
отвязанный от Nix-системы. Можно использовать тот же `emacs/base/`
с non-NixOS хоста — `pro-nix-emacs-sync.sh` делает именно это.

## Фаза 1: `early-init.el`

`emacs/base/early-init.el` запускается **до** активации `package.el`.
Устанавливает:

* `package-enable-at-startup = nil` — никогда не авто-устанавливать
  при первом старте.
* `package-quickstart-file` — указывает на
  `~/.config/emacs/quickstart.el` (в `user-emacs-directory`).
* `package-quickstart-sync = nil` — не перезаписывать quickstart-файл.
* `frame-inhibit-implied-resize = t` — без мерцания на первом фрейме.
* `inhibit-splash-screen = t`.

Также добавляет `modules/` в `load-path` (относительно файла), чтобы
`require 'pro-foo` в `init.el` работало, даже если `init.el` сам
загружается из `/nix/store/...`.

Best-effort: `(require 'treesit nil t)`, чтобы tree-sitter-символы
были доступны native-компиляции сторонних пакетов.

В GUI-фреймах: выключает fringes, ставит window-divider. Затем
грузит `pro-ui-theme`, чтобы тема была на месте до отрисовки
первого фрейма.

## Фаза 2: `init.el`

`emacs/base/init.el` — главный загрузчик. Делает:

1. Устанавливает `user-emacs-directory` в `~/.config/emacs/`.
2. Устанавливает `custom-file` в `~/.config/emacs/custom.el`
   (чтобы пользовательские настройки пережили
   `nixos-rebuild switch`).
3. `load custom.el`, если есть.
4. `setq pro-emacs-base-system-modules-dir` в каталог `modules/`
   репо.
5. `load pro-compat` и `pro-packages` рано, чтобы любой
   последующий модуль мог к ним обращаться.
6. Настраивает MELPA / ELPA-архивы через
   `pro-packages-configure-archives`.
7. `pro-packages-initialize` готовит package-систему.
8. `package-install-upgrade-built-in = t` — разрешает обновлять
   `transient` (идёт с Emacs, но для `magit` нужен свежее).
9. Добавляет `modules/` в `load-path`.
10. `load site-init.el`.
11. `pro-emacs-maybe-bootstrap-on-first-start` — на маркере, без
    сети на последующих стартах.
12. `pro-emacs-base-start` — собственно загрузчик модулей.

Финальный `provide 'pro-init` — для тестов / интроспекции.

## Фаза 3: `site-init.el`

`emacs/base/site-init.el` — **манифест модулей и резолвер**. Его
задача — прочитать манифест, найти файл каждого модуля (с
предпочтением user-override), и загрузить его.

### Манифест

```elisp
(defvar pro-emacs-base-default-modules
    '(pro-core pro-ui pro-packages pro-package-bootstrap pro-project pro-git
      pro-nix pro-js pro-ai pro-agent-shell pro-emcp pro-c pro-chat pro-telega pro-compat
      pro-completion pro-completion-keys pro-consult-helpers pro-dired
      pro-app-launcher pro-clipboard
      pro-emacs-check-fonts pro-exwm-sim pro-exwm pro-feeds pro-fix-corfu
      pro-haskell pro-java pro-key-utils pro-keys pro-lisp pro-markdown pro-nix-refresh
      pro-org pro-python pro-reload pro-session pro-history pro-spell pro-startup-metrics pro-profiler pro-tabs
      pro-terminals pro-test-helpers pro-tests pro-tests-keys pro-text
      pro-ui-completion pro-ui-fonts pro-ui-fringes pro-ui-icons
      pro-ui-improvements pro-buffer-banner pro-ui-modeline pro-ui-theme pro-ui-tty
      pro-dashboard pro-help pro-windows-popups
      pro-vterm-theme pro-windows pro-nav pro-docker)
  "Полный список модулей, загружаемых по умолчанию при старте Emacs.")
```

Пользователь может переопределить через `pro-emacs-modules` (или
`my-emacs-modules`, или `pro-emacs-base-modules`) в
`~/.config/emacs/modules.el`. См. snippets в стиле
`templates/decisions.el.example`.

### Резолвер

`pro-emacs-base--resolve-module` ищет в двух местах:

1. `~/.config/emacs/modules/<name>.el` (HM-деплой, user-override).
2. `pro-emacs-base-system-modules-dir/<name>.el` (модули репо).

User-override выигрывает **только если файл принадлежит
текущему пользователю**. Это защита от root-owned HM-файлов,
которые ломают Emacs:

```elisp
(user-owner-ok (or user-dir-symlink
                 user-file-symlink
                 (and user-attrs
                      (= (nth 2 user-attrs) (user-uid)))))
```

Если user-файл **не** принадлежит текущему пользователю, резолвер
предпочитает системный модуль и логирует сообщение `[pro-emacs]`.
Поэтому `helper-switch.sh` делает `chown -R $USER ~/.config/emacs`
после `nixos-rebuild switch`.

### Загрузка

`pro-emacs-base-start`:

```elisp
(dolist (module pro-emacs-base-default-modules)
  (let ((resolved-file (pro-emacs-base--resolve-module module)))
    (if resolved-file
        (condition-case err
            (load resolved-file nil t)
          (error (message "[pro-emacs] failed to load %s: %S" resolved-file err)))
      (message "[pro-emacs] missing module: %s" module))))
```

Идемпотентно: каждая top-level форма модуля защищена
`pro-compat--add-hook-once` и подобными, так что re-evaluation не
пере-устанавливает hooks, не пере-добавляет в списки, не
пере-применяет advice.

### `provided-packages.el`

`site-init.el` сначала пробует загрузить
`~/.config/emacs/provided-packages.el` (HM-деплой). Если файл
отсутствует **или** не доступен для записи (признак того, что им
владеет HM), откатывается на копию репо в
`emacs/base/provided-packages.el`.

Содержимое файла — `(setq pro-packages-provided-by-nix '(magit
vertico consult …))` — те же 58 имён, что и в
`emacs/core.nix#pro.emacs.providedPackages`.

`pro-packages.el` обращается к `pro-packages-provided-by-nix`,
чтобы решить: «этот пакет дан Nix, или мне ставить из MELPA?».

### Pending-биндинги

После загрузки всех модулей `site-init.el` вызывает
`pro-keys-apply-pending` и `pro-keys-report-pending`. Первая
пере-применяет глобальные клавиши, которые были отложены, потому
что их целевой пакет ещё не загружен; вторая печатает сводку
pending-биндингов, чтобы пользователь мог `M-x package-install`
необходимые пакеты.

## Фаза 4: `pro-emacs-base-start`

Здесь происходит собственно работа. Это функция
`pro-emacs-base-start`, вызываемая из `init.el:50`. Она
итерирует манифест, резолвит каждый модуль и загружает его.
Функция **идемпотентна**: можно вызвать дважды, и второй вызов —
no-op (потому что `provide` защищён `(featurep 'pro-foo)`, а
top-level формы защищены).

После загрузки всех модулей вызываются
`pro-keys-apply-pending` и `pro-keys-report-pending`. Затем
`pro--reconstruct` (если предоставлен `pro-epistemology.el`)
восстанавливает эпистемическое состояние из сохранённого
снапшота — это фича «сохрани мои мысли между перезагрузками».

## Контракт soft-reload

`emacs/base/modules/pro-reload.el` определяет:

```elisp
(defvar pro--before-reload-hook nil)
(defvar pro--after-reload-hook  nil)

(defun pro/before-reload (fn) ...)
(defun pro/after-reload  (fn) ...)
(defun pro--forget-file-in-load-history (file) ...)
(defun pro/reload-module (module) ...)
(defun pro/reload-all-modules () ...)
(defun pro/reload-config (&optional full) ...)
```

`pro--forget-file-in-load-history` удаляет файл из `load-history`
и `unload-feature`'ит предоставленную фичу, чтобы следующий
`load` действительно переоценил файл (без этого Emacs видит
совпадающий mtime и тихо пропускает).

`pro/reload-config`:

1. Обновить Nix-сгенерированные пути (если скрипт доступен).
2. `run-hooks 'pro--before-reload-hook` (модули tear down child
   frames, фоновые процессы, кэшированный state).
3. Если `full`, re-eval `site-init.el` (так что манифест и
   `provided-packages.el` подхватывают изменения); затем
   `pro/reload-all-modules`. Иначе — только
   `pro/reload-all-modules`.
4. Re-apply клавиши, шрифты, fringes, completion, иконки, modeline,
   тему.
5. `run-hooks 'pro--after-reload-hook` (модули пере-создают
   persistent state из свежезагруженного кода).
6. Печатает сводку с затраченным временем.

### Чек-лист автора модуля

Из шапки `pro-reload.el`:

> Reload contract for module authors:
>
> * Re-evaluating a module via `pro/reload-module` always runs the
>   *current* contents of the .el file (we drop the load-history
>   entry, so mtime tricks with .elc don't mask changes).
> * Modules that own persistent state (child frames, background
>   processes, globalised variables) should register a teardown
>   function on `pro--after-reload-hook` so a reload actually
>   re-creates that state from the freshly-loaded code. Use
>   `pro/after-reload #'my-reset-fn`.
> * Modules should keep their top-level forms idempotent (use the
>   `pro-compat--add-hook-once` / `add-to-list-once` /
>   `advice-add-once` helpers) — re-evaluation will re-run them
>   on every reload.

Три правила. Первое поддерживается
`pro--forget-file-in-load-history` — вам ничего не нужно делать.
Второе — **ваша** работа. Третье поддерживается
`pro-compat`-хелперами.

## Манифест — это данные

Поскольку `pro-emacs-base-default-modules` — `defvar` (а не
`defconst`), пользователь может переопределить его из
`~/.config/emacs/modules.el` в load-time. Это **единственный**
способ кастомизировать манифест — per-host NixOS-опции для этого
нет.

`templates/decisions.el.example` — стартовая точка:

```elisp
(setq pro-emacs-modules
      '(pro-core pro-ui pro-...))
```

`site-init.el` читает этот файл первым (`load-file
pro-emacs-base-user-manifest`), затем откатывается на
`pro-emacs-base-default-modules`.

## `~/.config/emacs/decisions.el`

Решения — per-package override'ы, не per-module:

```elisp
(setq pro-packages-decisions
      '((gptel . always)        ; всегда ставить из MELPA, даже если Nix даёт
        (magit . always)
        (somepkg . never)))     ; никогда не ставить, даже если просят
```

`pro-packages.el` проверяет `pro-packages-decisions` перед
auto-установкой отсутствующего пакета. Это позволяет пользователю
opt-out из конкретных пакетов без удаления модуля, который их
тянет.
