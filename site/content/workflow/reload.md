+++
title = "Soft-reload"
template = "page.html"
weight = 6

[extra]
tldr = "C-x M-c (pro/reload-config) переоценивает каждый загруженный модуль в месте. C-u re-evals site-init.el первым. Модули, владеющие persistent state, регистрируются на pro--after-reload-hook. Идемпотентные top-level формы через pro-compat--add-{hook,to-list,advice}-once."

[[extra.next]]
title = "Тесты"
url = "/workflow/tests/"

[[extra.next]]
title = "Per-host чек-лист"
url = "/workflow/per-host/"
+++

# Soft-reload

`M-x pro/reload-config` (**C-x M-c**) переоценивает каждый
загруженный модуль **в месте**. Это вторая по частоте команда в
проекте (после `M-x`).

## Что она делает

```elisp
(defun pro/reload-config (&optional full)
  "Reload the whole pro Emacs configuration to apply changes
without restarting.

If FULL is non-nil (or called with a prefix argument), re-eval
site-init.el from disk (which re-runs provided-packages loading
and the top-level init) AND re-load every module. The non-full
path re-evaluates each module's .el file in place.

Both paths run pro--before-reload-hook (modules can tear down
child frames / bg processes / cached state) and
pro--after-reload-hook (modules re-create persistent state
from the freshly loaded code)."
  (interactive "P")
  ...)
```

Полная последовательность (не-full путь):

1. Обновить Nix-сгенерированные пути (если скрипт доступен).
2. `run-hooks 'pro--before-reload-hook` — модули tear down.
3. `pro/reload-all-modules` — выбросить каждый модуль из
   `load-history`, затем `load-file` его. Хелпер
   `pro--forget-file-in-load-history` удаляет соответствующую
   запись из `load-history` и `unload-feature`'ит
   предоставленную фичу.
4. `pro-keys-reload` + `pro-keys-apply-pending` +
   `pro-keys-report-pending` — пере-применить глобальные клавиши.
5. `pro--reconstruct` (если `pro-epistemology.el` загружен) —
   восстанавливает эпистемическое состояние из сохранённого
   снапшота.
6. Пере-применить UI-настройки: шрифты, fringes, completion,
   иконки, modeline, тему.
7. `run-hooks 'pro--after-reload-hook` — модули пере-создают
   persistent state.
8. Печатает затраченное время.

Full-путь добавляет шаг 3.5: re-eval `site-init.el` первым. Это
полезно, когда изменился манифест или `provided-packages.el`.

## Почему `pro--forget-file-in-load-history`

Emacs использует `load-history` как источник правды о том,
«загружен» ли файл и «актуален» ли он. Если mtime файла совпадает
с записанным временем загрузки, `load` тихо пропускает
переоценку — даже когда пользователь явно просит reload.

```elisp
(defun pro--forget-file-in-load-history (file)
  "Remove all load-history entries whose file is FILE (or its .elc).
Also unbind features provided by the file."
  ...)
```

Этот хелпер:

1. Проходит по `load-history` и удаляет записи, чей `car` — это
   `file` (или его `file-truename`, или его `.elc`).
2. Собирает фичи, предоставленные этими записями.
3. `unload-feature` каждую, так что следующий `provide` будет
   «настоящим».
4. Удаляет соответствующий `.elc` из `load-history` тоже (чтобы
   свежий `.el` выигрывал у устаревшего `.elc`).

После этого следующий `load-file file` переоценивает файл с нуля.

## Контракт автора модуля

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

## Хелперы `pro-compat`

```elisp
(pro-compat--add-hook-once       'some-hook  #'some-function)
(pro-compat--add-to-list-once    'some-list  'some-symbol)
(pro-compat--advice-add-once     'some-fn :before #'some-wrapper)
```

Каждый — тонкая обёртка, которая проверяет `memq` (для hooks),
`member` (для lists) или `advice-member-p` (для advice) перед
добавлением. Это делает top-level формы безопасными для
переоценки.

Без этих хелперов soft-reload добавлял бы один и тот же хук
дважды, один и тот же элемент списка дважды, или двойную обёртку
advice. Результат: тонкие баги (например, функция запускается
дважды после каждого reload), которые проявляются только на
втором или третьем reload.

## Паттерн teardown

Для модуля, который создаёт child-frame на load:

```elisp
(defun pro-mine--reset ()
  "Teardown for pro-mine. Called on pro--after-reload-hook."
  (when (frame-live-p pro-mine--frame)
    (delete-frame pro-mine--frame))
  (setq pro-mine--frame nil
        pro-mine--cache nil))

(when (fboundp 'pro/after-reload)
  (pro/after-reload #'pro-mine--reset))
```

Reset-функция:

1. Проверяет, что frame всё ещё жив.
2. Удаляет его.
3. Сбрасывает module-level cache-переменные.
4. В следующий раз, когда модульная "show"-функция запустится
   (после reload пользователь делает то, что её триггерит), frame
   пересоздаётся с геометрией свежезагруженного кода.

Канонический пример — `pro-buffer-banner.el`. Reset-функция — в
`emacs/base/modules/pro-buffer-banner.el:737-760`.

## Soft reload vs hard restart

| | Soft reload (C-x M-c) | Hard restart |
|---|------------------------|---------------|
| Скорость | < 1 с | 5-10 с |
| Состояние | Раскладки фреймов, терминальные буферы, magit, … выживают | Всё потеряно |
| Persistent state модуля | Сбрасывается `pro--after-reload-hook` | Всё уходит |
| Web-mode, LSP-серверы | Остаются (они external-процессы) | Нужно перезапускать |
| Изменение `provided-packages.el` | Не подхватывается — используйте `C-u` для re-eval `site-init` | Подхватывается |
| Изменение манифеста | Не подхватывается — используйте `C-u` | Подхватывается |
| Баг в модуле | Reload покажет его как явную ошибку в `*Messages*` | Может зависнуть при старте |

Общее правило: используйте soft reload для «я отредактировал
функцию и хочу её протестировать». Используйте hard restart для
«я отредактировал манифест или `provided-packages.el`» или
«soft reload ведёт себя плохо».

## Escape hatch `pro/session-save-and-restart-emacs`

Для редкого случая, когда soft reload недостаточен, но вы не
хотите терять сессию:

```elisp
M-x pro/session-save-and-restart-emacs
```

Это:

1. Вызывает `pro/session-save`, чтобы записать
   `~/.emacs.d/.pro-session.el` (открытые файлы + point + window
   state).
2. Стартует новый Emacs-сабпроцесс, который загружает сохранённую
   сессию.
3. Убивает текущий Emacs.

Результат: свежий Emacs со всеми файлами и состоянием окон,
которые были у вас до.

## Soft-reload всего сайта

Если вы редактируете `emacs/base/modules/pro-reload.el` сам,
soft reload не подхватит изменение (модуль, который выполняет
reload, не может перезагрузить себя). Нужно:

* `M-x pro/reload-module pro-reload` — перезагружает только этот
  модуль.
* `C-u M-x pro/reload-config` — full reload (re-evals `site-init`
  + все модули).
* Перезапустить Emacs — последнее средство.

## Типичные проблемы

| Симптом | Причина | Фикс |
|---------|---------|-------|
| "Module not owned by current user" на каждом reload | sudo-активация записала файлы под root | `sudo chown -R $USER ~/.config/emacs` (helper-switch.sh делает это) |
| Reload вроде ничего не делает | mtime-трюк — `load-history` думает, что файл актуален | Проверьте, что хелпер `pro--forget-file-in-load-history` запустился (он по умолчанию) |
| Frame выживает после reload, но в неправильной позиции | У модуля нет reset-функции на `pro--after-reload-hook` | Добавьте одну (см. паттерн teardown выше) |
| Функция вызывается дважды после reload | Top-level форма модуля не идемпотентна | Оберните в `pro-compat--add-{hook,to-list,advice}-once` |
| Reload падает с "Cannot open load file" | Модуль удалён, но манифест всё ещё ссылается | Удалите из `pro-emacs-base-default-modules` в `site-init.el` |
