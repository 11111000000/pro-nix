;;; pro-agent-shell.el --- Адаптер для пакета agent-shell -*- lexical-binding: t; -*-
;; Назначение: гарантировать, что `pro-agent-open` доступна и что модуль
;; загружается безопасно в отсутствие самого пакета agent-shell.
;; Правило: файл должен всегда быть синтаксически корректным и не вызывать ошибок
;; при require в минимальном окружении (CI, контейнеры).

;; Реализация минималистична: задаёт точку входа и аккуратно пытается
;; загрузить опциональные функции из agent-shell и emcp.

(defvar pro-agent-shell--emcp-path
  (let* ((this-file (or load-file-name
                        (and (boundp 'byte-compile-current-file) byte-compile-current-file)
                        buffer-file-name))
         (module-dir (and this-file (file-name-directory this-file)))
         (repo-root (and module-dir
                         (locate-dominating-file module-dir ".git"))))
    (and repo-root
         (expand-file-name "submodules/emcp" repo-root)))
  "Путь к EMCP submodule. Вычисляется относительно расположения этого файла в репозитории.")

(defvar pro-agent-shell--core-path
  (let* ((this-file (or load-file-name
                        (and (boundp 'byte-compile-current-file) byte-compile-current-file)
                        buffer-file-name))
         (module-dir (and this-file (file-name-directory this-file)))
         (repo-root (and module-dir
                         (locate-dominating-file module-dir ".git"))))
    (and repo-root
         (expand-file-name "submodules/agent-shell" repo-root)))
  "Путь к agent-shell submodule. Вычисляется относительно расположения этого файла в репозитории.

Используется в самом конце этого модуля (см. блок
\"Submodule override\") для `load-file' submodule-версии
`agent-shell-ui.el'.  Это rebinds `agent-shell-ui-*' defuns (включая
`agent-shell-ui--append-body', который держит фикс дублирования
thinking-чанков) поверх MELPA-версии, не трогая load-path и не
ломая `require' паттерны других модулей.

На горячем reload (`M-x pro/reload-config') top-level код модуля
выполняется заново, и `load-file' внизу перебиндит функции из
submodule-версии — даже если feature `agent-shell' уже загружен из
MELPA.  Это нужно, чтобы локальные правки в submodule
(например, `agent-shell-ui.el') подхватывались без `kill-emacs'.")

(defvar-local pro-agent-shell--project-name-cache nil
  "Cached enriched project name: (CACHE-KEY . VALUE).
CACHE-KEY is (DIR . HEAD-MTIME); refreshed only when HEAD changes.")

(defvar-local pro-agent-shell--refresh-timer nil
  "Buffer-local timer that re-renders the agent-shell header.")

(defun pro-agent-open ()
  "Открыть agent-shell, если он доступен в runtime.

Если пакет доступен и предоставляет интерактивную команду `agent-shell',
вызываем её. В противном случае выводим информативное сообщение.
"
  (interactive)
  (if (or (featurep 'agent-shell) (require 'agent-shell nil t))
      (if (fboundp 'agent-shell)
          (call-interactively #'agent-shell)
        (message "[pro-agent-shell] пакет agent-shell загружен, но команда agent-shell недоступна"))
    (let ((declared (and (boundp 'pro-packages-provided-by-nix)
                         (memq 'agent-shell pro-packages-provided-by-nix))))
      (if declared
          (message "[pro-agent-shell] пакет agent-shell объявлен Nix, но не найден в runtime. Проверьте профиль / home-manager.")
        (message "[pro-agent-shell] пакет agent-shell не найден. Можно временно установить через M-x pro-packages-install RET agent-shell")))))

;; Подключаем EMCP submodule к load-path (если доступен)
(when (and pro-agent-shell--emcp-path
           (file-directory-p pro-agent-shell--emcp-path)
           (not (member pro-agent-shell--emcp-path load-path)))
  (push pro-agent-shell--emcp-path load-path))

;; Попытки необязательной интеграции — выполняются в безопасном ignore-errors.
(ignore-errors
  ;; transient не обязателен; пытаемся загрузить без ошибки.
  (require 'transient nil t)
  (require 'agent-shell nil t)
  ;; agent-shell-hud — многоязычный пульт и индикатор состояния.
  ;; Подключается через global minor mode, который сам ставит
  ;; локальную клавишу в `agent-shell-mode-map'.
  (require 'agent-shell-hud nil t))

;; ---- Buffer name: drop the "OpenCode Agent" prefix ----
;; Default format produces names like "OpenCode Agent @ proj:branch+wt:name"
;; (see `agent-shell--format-buffer-name'). The provider portion is identical
;; across every agent-shell tab, which is wasted space in tab-bar / tab-line
;; / modeline / `C-x b'. The public defcustom `agent-shell-buffer-name-format'
;; accepts a function (AGENT PROJECT) -> STRING; we keep project (already
;; enriched by the advice below) and prepend a single visual marker.
;;
;; Emoji works in TTY and graphical frames without nerd-fonts. If you want
;; the nerd-icons robot, swap for: (all-the-icons-faicon "robot" :height 0.9)
(when (require 'agent-shell nil t)
  (setq agent-shell-buffer-name-format
        (lambda (agent project)
          (format "🤖 %s" (if (and (stringp project) (not (string-empty-p project)))
                              project
                            "agent")))))

;; Если пакет доступен — зарегистрируем небольшие обёртки и локальные клавиши.
(condition-case err
    (when (require 'agent-shell nil t)
      ;; Минималистичный заголовок вместо баннера
      (setq agent-shell-header-style 'text
            agent-shell-show-welcome-message nil)

      ;; История сессий: agent-shell не хранит её сам — список берётся
      ;; через ACP `session/list` от запущенного агента. Opencode
      ;; поддерживает list/load/resume, поэтому стратегия 'latest
      ;; автоматически подгрузит последнюю сессию при старте нового
      ;; буфера, без интерактивного picker. Если хотите выбор — поменяйте
      ;; на 'prompt'.
      (setq agent-shell-session-strategy 'prompt
            agent-shell-session-restore-verbosity 'full
            agent-shell-show-session-id t)

      ;; Transcript: держим дефолт — `agent-shell--default-transcript-file-path'.
      ;; При не-nil функции agent-shell:
      ;;   1. сам выбирает имя файла (.agent-shell/transcripts/YYYY-MM-DD-HH-MM-SS.md),
      ;;   2. fmakunbound-ит `agent-shell-save-session-transcript'
      ;;      (убирает `read-file-name' на C-x C-s),
      ;;   3. ставит `shell-maker-prompt-before-killing-buffer' в nil
      ;;      (убирает "Save transcript for *Agent*?" в y-or-n-p при
      ;;      kill-buffer и `save-buffers-kill-emacs').
      ;; Раньше здесь стояло `nil' ради "перформанса при тяжёлом трафике",
      ;; но фактический hot-path — это fork+exec git, который уже починен
      ;; в `pro-agent-shell--project-name' (читает .git/HEAD напрямую).
      ;; Запись `write-region APPEND' дёшева и не блокирует основной поток.
      ;; Если всё-таки захочется выключить — `M-x agent-shell-hud-toggle-transcript'
      ;; или `t' в HUD-меню (C-c a).

      ;; EMCP — MCP-сервер: даёт агенту доступ к Emacs (документация,
      ;; eval, скриншоты, переменные). Профиль develop даёт inspect +
      ;; get-variable, set-variable, screenshot.
      (when (require 'emcp nil t)
        (setq emcp-default-profile 'develop)
        (pro-compat--add-to-list-once 'agent-shell-mcp-servers
                                     '((name . "emcp")
                                       (type . "http")
                                       (headers . ())
                                       (url . (lambda ()
                                                (require 'emcp)
                                                (let ((server (emcp-start emcp-default-profile)))
                                                  (emcp-server-url server)))))))
      (defun pro-agent-shell--maybe-call (fn &rest args)
        "Вызвать FN если он определён, иначе показать сообщение.
Аргументы передаются в FN напрямую." (apply (if (fboundp fn) fn (lambda (&rest _) (message "[pro-agent-shell] %s недоступна" fn))) args))

      (defun pro-agent-shell--setup-keys ()
        "Установить локальные клавиши и локальные опции в буфере agent-shell, если режим доступен."
        (when (derived-mode-p 'agent-shell-mode)
          (when (fboundp 'agent-shell-set-session-model)
            (local-set-key (kbd "C-c m") #'agent-shell-set-session-model))
          ;; comint переопределяет truncate-lines в t, из-за чего длинные
          ;; строки вывода (markdown, код, json) режутся по правому краю
          ;; окна. Включаем мягкий перенос по словам, чтобы конец вывода
          ;; был виден целиком.
          (setq-local word-wrap t)
          (setq-local truncate-lines nil)))

      (when (boundp 'agent-shell-mode-hook)
        (pro-compat--add-hook-once 'agent-shell-mode-hook #'pro-agent-shell--setup-keys))
      (when (boundp 'agent-shell-hook)
        (pro-compat--add-hook-once 'agent-shell-hook #'pro-agent-shell--setup-keys))
      ;; На крайний случай — добавим advice на команду открытия, если она есть.
      (when (fboundp 'agent-shell)
        (defun pro-agent-shell--after-start (&rest _)
          "Re-apply setup keys after `agent-shell' starts. Defun form keeps
`advice-add' idempotent across `pro/reload-config' reloads."
          (pro-agent-shell--setup-keys))
        (pro-compat--advice-add-once #'agent-shell :after #'pro-agent-shell--after-start))

      ;; ---- Project / branch / worktree info in header ----
      ;; Project name: append ":<branch>" and "+wt:<name>" when in a git repo
      ;; and a worktree. We wrap `agent-shell--project-name' so the existing
      ;; header rendering picks up the enriched name automatically.
      ;;
      ;; Performance: the wrapper fires on a 5-second timer per agent-shell
      ;; buffer. Doing fork+exec of git here showed up as ~35% of total CPU in
      ;; profiles. We replace the shell-outs with direct reads of `.git/HEAD'
      ;; and cache the result keyed on the HEAD file mtime so we recompute only
      ;; when the user actually switches branch.
      (defun pro-agent-shell--read-trimmed (path)
        "Return PATH contents trimmed, or nil if unreadable."
        (when (and path (file-readable-p path))
          (condition-case _err
              (with-temp-buffer
                (insert-file-contents-literally path)
                (string-trim (buffer-string)))
            (error nil))))

      (defun pro-agent-shell--resolve-gitdir (dir)
        "Return absolute gitdir for working tree DIR, or nil.
Handles both regular repos (.git is a directory) and worktrees
(.git is a file with `gitdir: <path>')."
        (let ((dot-git (expand-file-name ".git" dir)))
          (cond
           ((file-directory-p dot-git) dot-git)
           ((file-regular-p dot-git)
            (let ((c (pro-agent-shell--read-trimmed dot-git)))
              (when (and c (string-match "\\`gitdir:[ \t]*\\(.+\\)\\'" c))
                (expand-file-name (match-string 1 c) dir))))
           (t nil))))

      (defun pro-agent-shell--branch-from-head (head)
        "Extract branch name (or short SHA) from raw HEAD file contents."
        (cond
         ((null head) nil)
         ((string-match "\\`ref:[ \t]*refs/heads/\\(.+\\)\\'" head)
          (match-string 1 head))
         ((string-match "\\`[0-9a-f]\\{7,40\\}\\'" head)
          (substring head 0 7))
         (t nil)))

      (defun pro-agent-shell--project-name ()
        "Return enriched project name (`proj:branch+wt:name' or `proj:branch').

Prefer the *main* project directory (not the worktree directory) when
`dir' resolves to a git worktree under `…/.git/worktrees/<name>/'.  This
keeps the project anchor stable in `C-x b' / tab-bar / modeline even
when the user is parked in a single-letter worktree like `t'.

Reads `.git/HEAD' directly, caches result by HEAD mtime. No fork/exec."
        (let* ((root (or (and (fboundp 'pro-project-root) (pro-project-root))
                         default-directory))
               (dir (and root (directory-file-name (expand-file-name root))))
               (gitdir (and dir (pro-agent-shell--resolve-gitdir dir)))
               ;; For worktrees (`…/.git/worktrees/<wt>/HEAD'), the main
               ;; project lives at the `commondir' sibling — the parent
               ;; of the worktree's gitdir, minus the `worktrees/' segment.
               ;; Fall back to `dir' when commondir is missing.
               (worktree (and gitdir
                             (string-match
                              "/worktrees/\\([^/]+\\)/?\\'" gitdir)
                             (match-string 1 gitdir)))
               (main-dir (if worktree
                             (let* ((gitdir-parent (file-name-directory
                                                    (directory-file-name gitdir)))
                                    (commondir (expand-file-name
                                                ".." gitdir-parent)))
                               (if (and (file-directory-p commondir)
                                        (string-match
                                         "/\\.git/?\\'" commondir))
                                   (directory-file-name
                                    (expand-file-name ".." commondir))
                                 dir))
                           dir))
               (proj (and main-dir
                          (not (string-equal
                                (expand-file-name main-dir)
                                (expand-file-name "~/")))
                          (file-name-nondirectory main-dir))))
          (when (and proj (not (string-empty-p proj)))
            (let* ((head-path (and gitdir (expand-file-name "HEAD" gitdir)))
                   (mtime (and head-path
                               (file-attribute-modification-time
                                (file-attributes head-path))))
                   (key (cons dir mtime)))
              (if (and pro-agent-shell--project-name-cache
                       (equal (car pro-agent-shell--project-name-cache) key))
                  (cdr pro-agent-shell--project-name-cache)
                (let* ((branch (pro-agent-shell--branch-from-head
                                (pro-agent-shell--read-trimmed head-path)))
                       (value (cond
                               ((and branch worktree)
                                (format "%s:%s+wt:%s" proj branch worktree))
                               (branch (format "%s:%s" proj branch))
                               (t proj))))
                  (setq pro-agent-shell--project-name-cache (cons key value))
                  value))))))

      (when (fboundp 'agent-shell--project-name)
        (defun pro-agent-shell--project-name-wrapper (orig-fn &rest args)
          "Return enriched project name; fall back to ORIG-FN on failure.
Skips ORIG-FN (which itself runs projectile-project-root) when our
fast path produces a valid name." 
          (or (condition-case _err (pro-agent-shell--project-name) (error nil))
              (apply orig-fn args)))
        (pro-compat--advice-add-once #'agent-shell--project-name :around #'pro-agent-shell--project-name-wrapper))

      ;; ---- Strip provider name from text header ----
      ;; The default text header starts with the buffer-name (provider, e.g.
      ;; "OpenCode"). We want only " <model> @ <project>". Strip the leading
      ;; propertized buffer-name token by trimming up to the first " ➤ " or
      ;; " @ ".
      (defun pro-agent-shell--strip-provider (header)
        "Strip leading provider (buffer-name) from HEADER text.
HEADER is the text header produced by `agent-shell--make-header'."
        (when (and header (stringp header))
          (let* ((trimmed (string-trim-left header)))
            (cond
             ;; Drop everything before the first " ➤ " (model name follows).
             ((string-match " ➤ " trimmed)
              (concat " " (substring trimmed (match-end 0))))
             ;; No model: drop everything before " @ " (project follows).
             ((string-match " @ " trimmed)
              (concat " " (substring trimmed (match-end 0))))
             (t trimmed)))))

      (when (fboundp 'agent-shell--make-header)
        (defun pro-agent-shell--header-wrapper (orig-fn state &rest args)
          "Strip provider name from agent-shell text header."
          (let ((result (apply orig-fn state args)))
            (if (and agent-shell-header-style
                     (eq agent-shell-header-style 'text))
                (pro-agent-shell--strip-provider result)
              result)))
        (pro-compat--advice-add-once #'agent-shell--make-header :around #'pro-agent-shell--header-wrapper))

      ;; ---- Periodic refresh of header so branch/worktree stay current ----
      ;; Performance: the timer fires per buffer; firing while the buffer is
      ;; not visible or while the user is in the minibuffer wastes CPU during
      ;; flyspell's `accept-process-output' window and inside completing-read.
      ;; Profiles showed this path consuming ~35% of total CPU.
      (defun pro-agent-shell--refresh-timer-fn ()
        "Timer callback: re-render header only when worth doing.
Skips when the buffer is not displayed in any visible window or when
the minibuffer is active (user is interacting with completion)." 
        (when (and (derived-mode-p 'agent-shell-mode)
                   (get-buffer-window (current-buffer) 'visible)
                   (not (active-minibuffer-window)))
          (ignore-errors (agent-shell--update-header-and-mode-line))))

      (defcustom pro-agent-shell-refresh-interval 15
        "Seconds between agent-shell header refreshes.
Branch/worktree information rarely changes; a longer interval reduces
CPU and GC pressure while keeping the header fresh enough to be useful."
        :type 'number
        :group 'pro)

      (defun pro-agent-shell--install-refresh-timer ()
        "Install a buffer-local timer that re-renders the header."
        (when (and (derived-mode-p 'agent-shell-mode)
                   (fboundp 'agent-shell--update-header-and-mode-line)
                   (not (timerp pro-agent-shell--refresh-timer)))
          (setq pro-agent-shell--refresh-timer
                (run-at-time pro-agent-shell-refresh-interval
                             pro-agent-shell-refresh-interval
                             #'pro-agent-shell--refresh-timer-fn))))

      (defun pro-agent-shell--cancel-refresh-timer ()
        "Cancel the agent-shell header refresh timer in the current buffer."
        (when (timerp pro-agent-shell--refresh-timer)
          (cancel-timer pro-agent-shell--refresh-timer)
          (setq pro-agent-shell--refresh-timer nil)))

      (when (boundp 'agent-shell-mode-hook)
        (pro-compat--add-hook-once 'agent-shell-mode-hook #'pro-agent-shell--install-refresh-timer))
      (add-hook 'kill-buffer-hook #'pro-agent-shell--cancel-refresh-timer nil t))
  (error (message "[pro-agent-shell] agent-shell integration skipped: %S" err)))

;; ---- agent-shell-hud integration ----
;; Если HUD загружен (см. require выше) — включим его глобально.
;; Клавиша `C-c a' (настраивается в `agent-shell-hud-menu-key')
;; ставится автоматически в `agent-shell-mode-map' при входе в шелл.
(condition-case err
    (when (fboundp 'agent-shell-hud-mode)
      (agent-shell-hud-mode 1))
  (error (message "[pro-agent-shell] HUD enable skipped: %S" err)))

;; Регистрация предлагаемых клавиш HUD (попадают в emacs-keys.org
;; через `pro/export-registered-keys-to-org'). Локальная клавиша
;; C-c a ставится самим HUD только в agent-shell-mode, глобального
;; конфликта с `pro-ai-open-entry' (тоже C-c a) не возникает,
;; потому что приоритет у mode-local.
(condition-case _err
    (with-eval-after-load 'pro-keys
      (when (fboundp 'pro/register-module-keys)
        (pro/register-module-keys
         'agent-shell-hud
         `(("C-c a" . agent-shell-hud-menu)
           ("C-c i" . agent-shell-hud-info)
           ("C-c r" . agent-shell-hud-refresh)))))
  (error nil))

(defun pro-agent-install ()
  "Убедиться, что пакет `agent-shell' доступен.

Если пакет отсутствует в runtime, попытаемся установить его из MELPA
через политику `pro/packages-ensure` с разрешением fallback (allow-melpa).
Команда безопасна для вызова вручную и выводит читаемое сообщение о результате.
"
  (interactive)
  (condition-case err
      (let ((ok (pro/packages-ensure 'agent-shell t)))
        (if ok
            (if (require 'agent-shell nil t)
                (message "[pro-agent-shell] agent-shell доступен")
              (message "[pro-agent-shell] пакет установлен, но не найден в load-path — перезапустите Emacs"))
          (message "[pro-agent-shell] не удалось обеспечить agent-shell (pro/packages-ensure вернул nil)")))
    (error (message "[pro-agent-shell] ошибка при попытке обеспечить agent-shell: %S" err))))

;; ---------------------------------------------------------------------------
;; Soft reload integration
;; ---------------------------------------------------------------------------
;; Advice on `agent-shell--project-name' is re-applied via
;; `pro-compat--advice-add-once' on every reload, so the wrapper will use
;; the freshly loaded `pro-agent-shell--project-name' the next time it's
;; called. The buffer-name-format lambda is also re-set at top level
;; during reload, so NEW agent-shell buffers get the new format.
;;
;; Existing buffers keep their old names — that's intrinsic to Emacs
;; (renaming user buffers is invasive).  The reload-evaluated code will
;; produce the new format on the next `agent-shell' call.
;;
;; The cache `pro-agent-shell--project-name-cache' is buffer-local and
;; keyed on (DIR . HEAD-MTIME); if a user edits the project's
;; `pro-agent-shell--project-name' logic, the next call will compute
;; fresh against the new code and the new key.

;; ---------------------------------------------------------------------------
;; Submodule override: load the agent-shell submodule's `agent-shell-ui.el'
;; last, after all top-level `require' calls above have run.  The submodule
;; path is NOT pushed onto `load-path' here — only the explicit file is
;; loaded.  This rebinds `agent-shell-ui-*' defuns (notably
;; `agent-shell-ui--append-body' and friends) to the submodule's version
;; even when the `agent-shell' feature was loaded from a different
;; directory (MELPA, Nix site-lisp) earlier in startup.  Effect: local
;; edits in `submodules/agent-shell/agent-shell-ui.el' take effect on
;; `M-x pro/reload-config' without restarting Emacs.
;;
;; Position matters: this block runs AFTER the top-level
;; `(when (require 'agent-shell nil t) ...)' calls above (lines ~109 and
;; ~118).  Emacs has a quirk where the first failed `(require FEATURE
;; nil t)' returns nil silently, but subsequent calls re-raise the cached
;; file-error.  If we pushed the submodule to `load-path' earlier, those
;; later `require' calls would re-signal the `acp' load error (the
;; submodule's `agent-shell.el' requires `acp').  By running this block
;; at the very end, we don't perturb the existing `require' behaviour.
(when (and pro-agent-shell--core-path
           (file-directory-p pro-agent-shell--core-path)
           (file-readable-p (expand-file-name "agent-shell-ui.el"
                                              pro-agent-shell--core-path)))
  (condition-case _err
      (load-file (expand-file-name "agent-shell-ui.el" pro-agent-shell--core-path))
    (error nil)))

(provide 'pro-agent-shell)

;;; pro-agent-shell.el ends here
