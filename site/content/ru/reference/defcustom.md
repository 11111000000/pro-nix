+++
title = "defcustom knobs"
sort_by = "weight"
template = "page.html"

[extra]
tldr = "Все ~76 пользовательских `defcustom` knob'ов в pro-*.el модулях, сгруппированных по `defgroup`."
+++

# defcustom knobs

<span class="gen-badge">auto-gen</span> Сгенерировано 2026-07-04 из `emacs/base/modules/pro-*.el`.

> Эта страница перечисляет каждый `defcustom`, экспонируемый pro-*.el модулями. Регенерируется через `just site-regen` из реального Emacs-исходника — если knob добавлен или удалён, эта страница меняется вместе.

**Всего knob'ов:** 76  ·  **Всего групп:** 23  ·  **Файлов просканировано:** 65

## Указатель групп

* [`(no group)`](#-no-group-) — 20 knobs
* [`pro`](#pro) — 5 knobs
* [`pro-ai`](#pro-ai) — 3 knobs
* [`pro-ai-anvil`](#pro-ai-anvil) — 2 knobs
* [`pro-ai-ellama`](#pro-ai-ellama) — 3 knobs
* [`pro-buffer-banner`](#pro-buffer-banner) — 13 knobs
* [`pro-completion`](#pro-completion) — 3 knobs
* [`pro-docker`](#pro-docker) — 1 knobs
* [`pro-emcp`](#pro-emcp) — 2 knobs
* [`pro-exwm`](#pro-exwm) — 1 knobs
* [`pro-haskell`](#pro-haskell) — 1 knobs
* [`pro-history`](#pro-history) — 5 knobs
* [`pro-profiler`](#pro-profiler) — 1 knobs
* [`pro-spell`](#pro-spell) — 1 knobs
* [`pro-tabs`](#pro-tabs) — 1 knobs
* [`pro-ui`](#pro-ui) — 7 knobs
* [`pro-ui-fonts`](#pro-ui-fonts) — 1 knobs
* [`pro-windows`](#pro-windows) — 1 knobs
* [`pro/chat`](#pro-chat) — 3 knobs
* [`pro/chat-telega`](#pro-chat-telega) — 2 knobs

---

## `(no group)` { #-no-group- }


| Knob | Default | Описание |
|------|---------|----------|
| `pro-ai-anvil-profile` | `default` | Профиль модулей anvil.el, которые нужно подгрузить.  Возможные значения:   - `default'   — `anvil-enable' без opt-in модулей: file / org / elisp /                   sqlite / shell (~40 tools).   - … |
| `pro-ai-backend` | `aitunnel` | Предпочтительный AI-backend. |
| `pro-ai-carriage-path` | `(let ((module-dir (file-name-director…` | flake.nix |
| `pro-ai-ellama-agentic-profile` | `default` | Какой профиль безопасности применять через `ellama-setup-agentic-coding'.  Возможные значения:   - `default'   — стандартные настройки: DLP enforce, irreversible block,                   agent loop… |
| `pro-ai-ellama-skill-dirs` | `(let* ((this-dir (file-name-directory…` | flake.nix |
| `pro-ai-ellama-srt-policy-file` | `(let* ((this-dir (file-name-directory…` | flake.nix |
| `pro-ai-models-file` | `(expand-file-name` | ai-models.json |
| `pro-ai-user-models-file` | `(expand-file-name` | ai-models.json |
| `pro-app-launcher-directories` | `(let ((home (or (and (getenv` | XDG_DATA_HOME |
| `pro-buffer-banner-position` | `:top` | Where to show the banner relative to the selected window. `:top'    — at the top of the window. `:bottom' — at the bottom of the window. |
| `pro-emcp-server-profile` | `full-control` | Профиль EMCP, который стартует автоматически.  `full-control' = inspect + develop + eval + send-keys. `eval' и `send-keys' гейтнуты политикой `emcp-tools-eval-default-policy' / `emcp-tools-send-key… |
| `pro-history-xdg-cache-home` | `(or (and (getenv` | XDG_CACHE_HOME |
| `pro-history-xdg-state-home` | `(or (and (getenv` | XDG_STATE_HOME |
| `pro-ui-corfu-colors` | `false` | Alist overriding Corfu face colors. Each element is (FACE . ATTRS) where FACE is `default' or `current' and ATTRS is a plist accepted by `set-face-attribute'. When nil (the default), colors are aut… |
| `pro-ui-default-theme` | `tao-yang` | Symbolic name of theme to load by default at startup. Set to nil to disable automatic theme loading. Loading is guarded so missing packages don't error out (a message is shown instead). Works in bo… |
| `pro-ui-modeline-style` | `shaoline` | Стиль модельного слоя: 'minimal, 'shaoline или 'doom. По умолчанию — 'shaoline. Реализация попытается включить соответствующий пакет, если он доступен; при отсутствии пакета используется минимальна… |
| `pro-ui-shaoline-strategy` | `adaptive` | Стратегия shaoline-mode. - 'yin — обновления только по явному вызову `shaoline-update'. Минимум   активности, mode-line статичен между ручными апдейтами. - 'yang — полная активность: post-command-h… |
| `pro/chat-fill-column` | `80` | Ширина telega-chat-fill-column (nil — отключить). |
| `pro/profiler-default-mode` | `cpu` | Режим профилирования по умолчанию для `pro/profiler-start' и `pro/profiler-quick'. Допустимые значения: `cpu', `mem', `cpu+mem'. |
| `pro/telega-select-preview` | `echo` | Режим предпросмотра кандидата в `pro/telega-select-chat-or-contact': - echo: краткая подсказка в echo-area; - help-window: описание из telega-describe-*; - nil: без предпросмотра. |

## `pro` { #pro }

*Определён в [`pro-keys.el`](file:///home/za/pro-nix/emacs/base/modules/pro-keys.el).*

> Базовая группа настроек PRO.

Эта группа используется для общих `defcustom' переменных, которые не
попадают в узкоспециализированные подгруппы. При проектировании
интерфейса модуля мы предпочитаем явное именование групп, однако для
совместимости оставляем простой корневой `pro'.

| Knob | Default | Описание |
|------|---------|----------|
| `pro-agent-shell-refresh-interval` | `15` | Seconds between agent-shell header refreshes. Branch/worktree information rarely changes; a longer interval reduces CPU and GC pressure while keeping the header fresh enough to be useful. |
| `pro-core-gc-cons-percentage` | `0.3` | Steady-state value for `gc-cons-percentage' installed by pro-core. |
| `pro-core-gc-cons-threshold` | `(* 128 1024 1024)` | Steady-state value for `gc-cons-threshold' installed by pro-core. 128 MiB keeps GC pauses rare without making them painfully long; tune downward on memory-constrained hosts (Raspberry Pi, etc.). Ra… |
| `pro-dired-enable` | `true` | Enable pro dired helpers. Set to nil to disable. |
| `pro-dired-prefer-short` | `false` | If non-nil, use compact/short `ls' output in dired (one-file-per-line). Default is nil to preserve test compatibility and familiar long listing. |

## `pro-ai` { #pro-ai }

*Определён в [`pro-ai.el`](file:///home/za/pro-nix/emacs/base/modules/pro-ai.el).*

> AI integration for pro Emacs.

| Knob | Default | Описание |
|------|---------|----------|
| `pro-ai-auto-load-gptel` | `true` | Автоматически загружать gptel при старте Emacs, если пакет доступен. |
| `pro-ai-enable-carriage` | `true` | Если non-nil, попытаться загрузить carriage из `pro-ai-carriage-path'. |
| `pro-ai-enable-gptel-history` | `true` | Сохранять историю gptel-переписки. |

## `pro-ai-anvil` { #pro-ai-anvil }

*Определён в [`pro-ai-anvil.el`](file:///home/za/pro-nix/emacs/base/modules/pro-ai-anvil.el).*

> anvil.el — MCP-сервер в Elisp (file / org / elisp / sqlite).

| Knob | Default | Описание |
|------|---------|----------|
| `pro-ai-anvil-auto-start` | `false` | Если non-nil, запускать anvil-server при `after-init-hook'. По умолчанию nil — anvil тяжёлый и стартует по явному запросу. Включите в `custom.el', если MCP-сервер нужен постоянно. |
| `pro-ai-anvil-mcp-server-port` | `38913` | Порт для отладочного HTTP MCP-сервера anvil (если включён). Anvil по умолчанию говорит по stdio. Этот порт нужен только когда вы хотите curl-ом посмотреть, что вообще отвечает anvil. Не путать с `p… |

## `pro-ai-ellama` { #pro-ai-ellama }

*Определён в [`pro-ai-ellama.el`](file:///home/za/pro-nix/emacs/base/modules/pro-ai-ellama.el).*

> Ellama — Emacs client for local + cloud LLMs.

| Knob | Default | Описание |
|------|---------|----------|
| `pro-ai-ellama-agents-md-max-depth` | `8` | Максимальная глубина поиска AGENTS.md вверх по дереву. 8 = достаточно для прохождения через `home/<user>/Code/<project>/'. |
| `pro-ai-ellama-confirmations` | `true` | Если non-nil, оставлять ask-режим для tool confirmations после setup. При `nil' — выставить `ellama-tools-allow-all' (опасно; только для доверенной среды). По умолчанию t — это политика pro-nix. |
| `pro-ai-ellama-load-agents-md` | `true` | Если non-nil, при первом запуске Ellama пытается найти файлы инструкций вверх по дереву от `default-directory' и подключить их как project context. Какие файлы и в каком порядке — см. `pro-ai-ellam… |

## `pro-buffer-banner` { #pro-buffer-banner }

*Определён в [`pro-buffer-banner.el`](file:///home/za/pro-nix/emacs/base/modules/pro-buffer-banner.el).*

> Transient top banner showing buffer/project/branch on switch.

| Knob | Default | Описание |
|------|---------|----------|
| `pro-buffer-banner-debounce` | `0.2` | Minimum seconds between successive *display* calls. This is a pure display-side throttle, NOT a fade-restart trigger: even if a new display is allowed by the debounce, the running fade is NOT resta… |
| `pro-buffer-banner-duration` | `3.0` | Total seconds the banner stays visible (including fade-out).  Banner appears after a buffer/window switch, then stays fully visible for ~80% of this duration, with a short fade-out at the end. Thre… |
| `pro-buffer-banner-enable` | `true` | Non-nil to enable the transient buffer banner. |
| `pro-buffer-banner-fade-step-ms` | `50` | Milliseconds between fade steps. |
| `pro-buffer-banner-fade-steps` | `10` | Number of discrete steps in the fade-out animation. |
| `pro-buffer-banner-font-scale` | `0.7` | Scale factor for the banner font relative to the parent frame. 0.7 means ~70% the size of the default font (≈ 1/1.5 reduction). 1.0 means same size as the default. |
| `pro-buffer-banner-initial-alpha` | `95` | Frame alpha (0-100) when the banner appears. |
| `pro-buffer-banner-margin` | `0` | Pixel margin from the window edge (top or bottom, depending on `pro-buffer-banner-position'). 0 means \"one line height\" of the parent frame's font — enough to clear the mode-line or first line of… |
| `pro-buffer-banner-max-text-chars` | `80` | Maximum length of the banner text. If the composed text exceeds this, it is truncated with a trailing \"...\" so the frame stays narrow and predictable. Set to 0 to disable truncation. |
| `pro-buffer-banner-pad-chars` | `0` | Number of blank chars to pad around the text on each side. |
| `pro-buffer-banner-show-branch` | `true` | Show VCS branch (magit or vc) in the banner. |
| `pro-buffer-banner-show-project` | `true` | Show project name (via `pro-project-root') in the banner. |
| `pro-buffer-banner-theme-aware` | `true` | Non-nil derives banner colors from the current `default' face. The banner background is set to the default face's foreground (the text color of the parent frame) and the banner foreground to the de… |

## `pro-completion` { #pro-completion }

*Определён в [`pro-completion.el`](file:///home/za/pro-nix/emacs/base/modules/pro-completion.el).*

> Completion stack configuration for pro Emacs profile.

| Knob | Default | Описание |
|------|---------|----------|
| `pro-completion-auto-delay` | `0.25` | Delay before Corfu auto popup appears. |
| `pro-completion-auto-prefix` | `3` | Minimum prefix length before corfu auto-starts when `corfu-auto' is enabled. |
| `pro-completion-enable-posframe` | `false` | Enable corfu-posframe for child-frame based completion in GUI. Disable if you observe frame jitter on your setup. |

## `pro-docker` { #pro-docker }

*Определён в [`pro-docker.el`](file:///home/za/pro-nix/emacs/base/modules/pro-docker.el).*

> Docker integration helpers for pro-nix.

| Knob | Default | Описание |
|------|---------|----------|
| `pro-docker-enable` | `true` | Enable pro docker helpers (containers/images/volumes/networks buffers + tramp). |

## `pro-emcp` { #pro-emcp }

*Определён в [`pro-emcp.el`](file:///home/za/pro-nix/emacs/base/modules/pro-emcp.el).*

> EMCP HTTP-сервер для внешних MCP-клиентов.

| Knob | Default | Описание |
|------|---------|----------|
| `pro-emcp-server-auto-start` | `true` | Если non-nil, сервер стартует автоматически на `after-init-hook'. |
| `pro-emcp-server-port` | `38913` | Фиксированный TCP-порт для EMCP HTTP-сервера.  MCP-клиенты (pi, opencode) настроены на `http://127.0.0.1:<port>/mcp`. Меняйте здесь, если порт занят — синхронно обновите `local-templates/pi/mcp.jso… |

## `pro-exwm` { #pro-exwm }


| Knob | Default | Описание |
|------|---------|----------|
| `pro-exwm-urxvt--height-fraction` | `0.40` | Height of the urxvt bottom sidebar as a fraction of the display height. 0.40 ⇒ sidebar занимает 40% высоты экрана снизу.  Минимум — 200px. |

## `pro-haskell` { #pro-haskell }


| Knob | Default | Описание |
|------|---------|----------|
| `pro-haskell-enable-eglot` | `true` | If non-nil, automatically start HLS via eglot in Haskell buffers. HLS is heavy (it eagerly type-checks the whole package, often 1-2 GiB RSS and noticeable background I/O). Set to nil to fall back t… |

## `pro-history` { #pro-history }

*Определён в [`pro-history.el`](file:///home/za/pro-nix/emacs/base/modules/pro-history.el).*

> pro: runtime history, temp file policies, and Time Machine commands.

| Knob | Default | Описание |
|------|---------|----------|
| `pro-history-backup-retention-days` | `90` | Default age in days after which backups are considered for pruning. |
| `pro-history-enable-eyebrowse` | `false` | If non-nil, enable eyebrowse workspace management when available. |
| `pro-history-enable-undo-tree` | `true` | If non-nil, enable persistent undo via undo-tree when available. |
| `pro-history-max-kill-ring` | `400` | Maximum length of kill-ring for pro-history snapshots. |
| `pro-history-session-retention-days` | `365` | Default age in days after which session snapshots are pruned. |

## `pro-profiler` { #pro-profiler }

*Определён в [`pro-profiler.el`](file:///home/za/pro-nix/emacs/base/modules/pro-profiler.el).*

> Profiler helpers for pro-emacs.

| Knob | Default | Описание |
|------|---------|----------|
| `pro/profiler-quick-duration` | `15` | Длительность (сек) автоматической сессии `pro/profiler-quick'. |

## `pro-spell` { #pro-spell }

*Определён в [`pro-spell.el`](file:///home/za/pro-nix/emacs/base/modules/pro-spell.el).*

> Проверка орфографии на лету (hunspell + ru_RU).

| Knob | Default | Описание |
|------|---------|----------|
| `pro-spell-auto-enable` | `true` | Если non-nil, flyspell включается автоматически через хуки. При nil авто-включение отключено; пользователь может включить flyspell вручную через M-x flyspell-mode. |

## `pro-tabs` { #pro-tabs }

*Определён в [`pro-tabs.el`](file:///home/za/pro-nix/emacs/base/modules/pro-tabs.el).*

> Pro tabs integration (opt-in).

| Knob | Default | Описание |
|------|---------|----------|
| `pro-pro-tabs-enable` | `true` | Enable pro-tabs integration. When non-nil, configure tab-bar/tab-line and pro-tabs if available. This does not install global keybindings; use emacs-keys.org for that. |

## `pro-ui` { #pro-ui }


| Knob | Default | Описание |
|------|---------|----------|
| `pro-ai-carriage-enable-global-mode` | `false` | Если non-nil — включать `carriage-global-mode' после загрузки carriage. Оставьте nil по умолчанию: глобальный режим — опционален и может вмешиваться в интерактивные сессии. |
| `pro-terminals-enable` | `true` | Включить вспомогательные функции работы с терминалами (vterm/eshell).  Если установить в nil, модуль не будет подключать нигде дополнительных хэлперов. Этот флаг не управляет установкой пакетов: уб… |
| `pro-ui-cursor-bar-width` | `2` | Ширина вертикального бар-курсора в пикселях (используется как (bar . N)). |
| `pro-ui-cursor-readonly-line-width` | `1` | Толщина рамки полого прямоугольника в read-only буферах. |
| `pro-ui-enable-icons` | `true` | Включать ли иконки в UI-слое. |
| `pro-ui-enable-ligatures` | `true` | Включать ли лигатуры в коде. |
| `pro-ui-font-height` | `130` | Высота шрифта в десятых долях пункта. |

## `pro-ui-fonts` { #pro-ui-fonts }

*Определён в [`pro-ui-fonts.el`](file:///home/za/pro-nix/emacs/base/modules/pro-ui-fonts.el).*

> Настройки шрифтов и типографии для pro UI

| Knob | Default | Описание |
|------|---------|----------|
| `pro-ui-enable-mixed-pitch` | `false` | Включать mixed-pitch-mode для org-mode и help-mode по умолчанию. Опция выключена по умолчанию потому, что некоторые пользователи предпочитают моноширинные шрифты во всех буферах. |

## `pro-windows` { #pro-windows }

*Определён в [`pro-windows.el`](file:///home/za/pro-nix/emacs/base/modules/pro-windows.el).*

> Window and buffer management helpers for pro.

| Knob | Default | Описание |
|------|---------|----------|
| `pro-windows-enable` | `true` | Enable pro window management helpers. |

## `pro/chat` { #pro-chat }

*Определён в [`pro-chat.el`](file:///home/za/pro-nix/emacs/base/modules/pro-chat.el).*

> Настройки telega/Telegram для pro-конфигурации.

| Knob | Default | Описание |
|------|---------|----------|
| `pro/chat-history-limit` | `100` | Сколько последних сообщений подгружать в чат-буфер. |
| `pro/chat-use-docker` | `true` | Запускать telega-server через Docker вместо локального tdlib. Требует установленный Docker (см. virtualisation.docker в NixOS). Если `telega-server' уже доступен в PATH — можно поставить nil. |
| `pro/chat-use-tor` | `true` | Если non-nil, telega-server запускается через `telega-server-tor-launch' (прозрачный torsocks SOCKS5 → Tor, если доступен).  Когда Tor недоступен (например, AP не пробрасывает SOCKS5), fallback на … |

## `pro/chat-telega` { #pro-chat-telega }

*Определён в [`pro-telega.el`](file:///home/za/pro-nix/emacs/base/modules/pro-telega.el).*

> Дополнительные настройки telega (consult + CAPF).

| Knob | Default | Описание |
|------|---------|----------|
| `pro/telega-select-include-saved-messages` | `true` | Включать ли чат «Saved Messages» в начало списка (если он уже существует). |
| `pro/telega-select-show-unread` | `true` | Показывать ли краткую метку непрочитанного (u, @, rx) в аннотации. |

---

## Просканированные файлы

* `emacs/base/modules/pro-agent-shell.el` — 2 defcustom
* `emacs/base/modules/pro-ai-anvil.el` — 3 defcustom
* `emacs/base/modules/pro-ai-ellama.el` — 9 defcustom
* `emacs/base/modules/pro-ai.el` — 8 defcustom
* `emacs/base/modules/pro-app-launcher.el` — 1 defcustom
* `emacs/base/modules/pro-buffer-banner.el` — 14 defcustom
* `emacs/base/modules/pro-c.el` — 0 defcustom
* `emacs/base/modules/pro-chat.el` — 6 defcustom
* `emacs/base/modules/pro-clipboard.el` — 0 defcustom
* `emacs/base/modules/pro-compat.el` — 0 defcustom
* `emacs/base/modules/pro-completion-keys.el` — 0 defcustom
* `emacs/base/modules/pro-completion.el` — 3 defcustom
* `emacs/base/modules/pro-consult-helpers.el` — 0 defcustom
* `emacs/base/modules/pro-core.el` — 2 defcustom
* `emacs/base/modules/pro-dashboard.el` — 0 defcustom
* `emacs/base/modules/pro-dired.el` — 4 defcustom
* `emacs/base/modules/pro-docker.el` — 2 defcustom
* `emacs/base/modules/pro-emacs-check-fonts.el` — 0 defcustom
* `emacs/base/modules/pro-emcp.el` — 4 defcustom
* `emacs/base/modules/pro-epistemology.el` — 0 defcustom
* `emacs/base/modules/pro-exwm-sim.el` — 0 defcustom
* `emacs/base/modules/pro-exwm.el` — 1 defcustom
* `emacs/base/modules/pro-feeds.el` — 0 defcustom
* `emacs/base/modules/pro-fix-corfu.el` — 0 defcustom
* `emacs/base/modules/pro-git.el` — 0 defcustom
* `emacs/base/modules/pro-haskell.el` — 2 defcustom
* `emacs/base/modules/pro-help.el` — 0 defcustom
* `emacs/base/modules/pro-history.el` — 7 defcustom
* `emacs/base/modules/pro-java.el` — 0 defcustom
* `emacs/base/modules/pro-js.el` — 0 defcustom
* `emacs/base/modules/pro-key-utils.el` — 0 defcustom
* `emacs/base/modules/pro-keys.el` — 1 defcustom
* `emacs/base/modules/pro-lisp.el` — 0 defcustom
* `emacs/base/modules/pro-markdown.el` — 0 defcustom
* `emacs/base/modules/pro-nav.el` — 0 defcustom
* `emacs/base/modules/pro-nix-refresh.el` — 0 defcustom
* `emacs/base/modules/pro-nix.el` — 0 defcustom
* `emacs/base/modules/pro-org.el` — 0 defcustom
* `emacs/base/modules/pro-package-bootstrap.el` — 0 defcustom
* `emacs/base/modules/pro-packages.el` — 0 defcustom
* `emacs/base/modules/pro-profiler.el` — 2 defcustom
* `emacs/base/modules/pro-project.el` — 0 defcustom
* `emacs/base/modules/pro-python.el` — 0 defcustom
* `emacs/base/modules/pro-reload.el` — 0 defcustom
* `emacs/base/modules/pro-session.el` — 0 defcustom
* `emacs/base/modules/pro-spell.el` — 3 defcustom
* `emacs/base/modules/pro-startup-metrics.el` — 0 defcustom
* `emacs/base/modules/pro-tabs.el` — 1 defcustom
* `emacs/base/modules/pro-telega.el` — 3 defcustom
* `emacs/base/modules/pro-terminals.el` — 1 defcustom
* `emacs/base/modules/pro-test-helpers.el` — 0 defcustom
* `emacs/base/modules/pro-tests.el` — 0 defcustom
* `emacs/base/modules/pro-text.el` — 0 defcustom
* `emacs/base/modules/pro-ui-completion.el` — 0 defcustom
* `emacs/base/modules/pro-ui-fonts.el` — 1 defcustom
* `emacs/base/modules/pro-ui-fringes.el` — 0 defcustom
* `emacs/base/modules/pro-ui-icons.el` — 0 defcustom
* `emacs/base/modules/pro-ui-improvements.el` — 0 defcustom
* `emacs/base/modules/pro-ui-modeline.el` — 2 defcustom
* `emacs/base/modules/pro-ui-theme.el` — 1 defcustom
* `emacs/base/modules/pro-ui-tty.el` — 0 defcustom
* `emacs/base/modules/pro-ui.el` — 12 defcustom
* `emacs/base/modules/pro-vterm-theme.el` — 0 defcustom
* `emacs/base/modules/pro-windows-popups.el` — 0 defcustom
* `emacs/base/modules/pro-windows.el` — 1 defcustom
