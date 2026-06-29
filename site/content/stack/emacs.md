+++
title = "Слой Emacs"
template = "page.html"
weight = 2

[extra]
tldr = "Emacs 30, 64 pro-*.el модуля, четырёхфазный bootstrap, контракт soft-reload, тема tao-yang, Aporetic Sans, кастомный buffer banner, vertico+corfu+cape+orderless, эстетика tao."

[[extra.next]]
title = "Слой AI-агентов"
url = "/stack/ai/"

[[extra.next]]
title = "Загрузка Emacs"
url = "/architecture/emacs-base/"
+++

# Слой Emacs

Слой редактора — **Nix-provided**. ~58 Emacs-пакетов приходят из
`pkgs.emacsPackages` и становятся видны Emacs в build-time через
`EMACSLOADPATH`. Пользователю не нужно взаимодействовать с
`package.el` — `pro-packages.el` управляется политикой: сначала
Nix, затем fallback на MELPA, затем package-vc, с
`~/.config/emacs/decisions.el` как override.

## Что попадает в closure

`emacs/core.nix#pro.emacs.providedPackages` — 58 имён, включая
`magit`, `vertico`, `vertico-sort`, `orderless`, `marginalia`, `gptel`,
`consult`, `consult-dash`, `dash-docs`, `consult-eglot`,
`consult-yasnippet`, `corfu`, `cape`, `kind-icon`, `avy`,
`expand-region`, `yasnippet`, `projectile`, `treemacs`,
`consult-projectile`, `elfeed`, `eglot`, `rainbow-delimiters`,
`nix-mode`, `markdown-mode`, `mmm-mode`, `org`, `ob-mermaid`,
`vterm`, `multi-vterm`, `eshell-toggle`, `ace-window`, `undo-tree`,
`haskell-mode`, `haskell-snippets`, `which-key`,
`which-key-posframe`, `eldoc-box`, `keyfreq`, `helpful`, `popper`,
`buffer-expose`, `buffer-move`, `golden-ratio`, `embark`,
`embark-consult`, `exwm`, `xelb`, `agent-shell`, `agent-shell-hud`,
`acp`, `emcp`, `telega`, `transient`, `visual-fill-column`,
`pro-tabs`, `goto-chg`, `docker`, `tao-theme`, `shaoline`,
`nerd-icons`, `all-the-icons`, `treemacs-icons-dired`,
`eldoc-box`.

`providedPackages` — **это** каталог. Он регенерируется в
`~/.config/emacs/provided-packages.el` на каждой активации
(`emacs/core.nix:194-196`), так что свежий хост получает тот же
набор, что и `desktop`, с первого `pro-emacs-base-start`.

## Четырёхфазный bootstrap

| Фаза | Файл | Когда запускается |
|------|------|-------------------|
| 1. `early-init.el` | `emacs/base/early-init.el` | До активации package-системы |
| 2. `init.el` | `emacs/base/init.el` | Главная инициализация; устанавливает `user-emacs-directory` |
| 3. `site-init.el` | `emacs/base/site-init.el` | Манифест модулей + резолвер + загрузчик ключей |
| 4. `pro-emacs-base-start` | (в `site-init.el`) | Загружает каждый модуль из манифеста |

`early-init.el` делает то, что **должно** случиться до загрузки
любого пакета: `package-enable-at-startup = nil`, настройка
load-path, GUI-hygiene, best-effort `treesit` require.
`pro-ui-theme.el` тоже грузится здесь, чтобы тема была на месте
до отрисовки первого фрейма.

## Контракт soft-reload

`M-x pro/reload-config` (C-x M-c) переоценивает каждый
загруженный модуль **в месте**. С `C-u` сначала re-evals
`site-init.el`, так что свежеотредактированный манифест или
`provided-packages.el` вступает в силу.

Модули, у которых есть persistent state (child frames, фоновые
процессы, кэшированные значения), должны регистрировать teardown
на `pro--after-reload-hook`. Канонический пример — `pro-buffer-banner.el`:

```elisp
(when (fboundp 'pro/after-reload)
  (pro/after-reload #'pro-buffer-banner--reload-reset))
```

Reset-функция уничтожает persistent banner-frame и backing-буфер;
следующий `pro-buffer-banner--show` пересоздаёт их с геометрией
свежезагруженного кода.

## Визуальная идентичность

* **Тема** — `tao-yang` (светлая, по умолчанию) или `tao-yin`
  (тёмная). Устанавливается через `pro-ui-default-theme`.
* **Шрифт кода** — `Aporetic Sans Mono` 13pt. Устанавливается через
  `pro-ui-code-font-family`, `pro-ui-font-height`.
* **Текстовый шрифт** — `Aporetic Sans`. Устанавливается через
  `pro-ui-text-font-family`.
* **Курсор** — оранжевый `#ff8800` для русской раскладки, зелёный
  `#0d7a32` для английской, серый `#808080` для read-only буферов.
  Настраивается через `pro-ui-cursor-{russian,english,readonly}-color`.
* **Modeline** — `shaoline` (минималистичный). Настраивается через
  `pro-ui-modeline-style`.
* **Buffer banner** — child-frame вверху выбранного окна, показывает
  имя буфера + проект + ветку, theme-aware инвертированные цвета,
  3-секундный fade-out. См. [Справочник → defcustom → pro-buffer-banner](reference/defcustom.md).

## Стек completion

* **Vertico** (minibuffer, GUI + TTY) — плоский список, цикл,
  без popup.
* **Corfu** (in-buffer, GUI + TTY) — child-frame или in-buffer popup.
  `corfu-auto = t`, `corfu-auto-prefix = 3`, `corfu-auto-delay = 0.25`.
* **Cape** (CAPF-бэкенды) — `cape-file`, `cape-keyword`,
  `cape-dabbrev` (на `prog-mode-hook`), `cape-symbol`, `cape-history`,
  `cape-abbrev`, `cape-line`, `cape-dict`. Биндинги `C-c o
  {f, d, h, k, s, a, .}`.
* **Orderless** — нечёткий, используется в категориях `command` и
  `symbol`.
* **Consult** — `consult-line`, `consult-buffer`,
  `consult-ripgrep`, `consult-find`, `consult-imenu`,
  `consult-yasnippet`, `consult-eglot-symbols`.

Minibuffer получает `vertico`. Буфер получает `corfu`. Они не
сталкиваются, потому что `pro-completion--maybe-enable-corfu-in-minibuffer`
выключает `corfu-mode` и `corfu-auto`, когда `vertico--input` или
`mct--active` забиндены.

## Где живут глобальные клавиши

Источник — `emacs-keys.org`. Это **исполняемый код** — каждая
строка таблицы становится реальным `global-set-key` при старте
Emacs. Полная таблица — в [Справочник → Клавиши](reference/keys.md).

Per-user override'ы лежат в `~/.config/emacs/keys.org` (тот же формат
org-таблицы). Если оба файла существуют, оба парсятся по порядку;
user выигрывает на конфликте.
