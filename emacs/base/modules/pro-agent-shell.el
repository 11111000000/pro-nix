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
          (format "🤖 %s" (or (and (stringp project) (not (string-empty-p project)))
                              "agent")))))

;; Если пакет доступен — зарегистрируем небольшие обёртки и локальные клавиши.
(condition-case err
    (when (require 'agent-shell nil t)
      ;; Минималистичный заголовок вместо баннера
      (setq agent-shell-header-style 'text
            agent-shell-show-welcome-message nil)

      ;; Disable automatic transcript file creation/append to avoid
      ;; frequent disk I/O from agent-shell (helps performance under
      ;; heavy traffic). When nil, transcript saving is disabled.
      (when (boundp 'agent-shell-transcript-file-path-function)
        (setq agent-shell-transcript-file-path-function nil))

      ;; EMCP — MCP-сервер: даёт агенту доступ к Emacs (документация,
      ;; eval, скриншоты, переменные). Профиль develop даёт inspect +
      ;; get-variable, set-variable, screenshot.
      (when (require 'emcp nil t)
        (setq emcp-default-profile 'develop)
        (add-to-list 'agent-shell-mcp-servers
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
        (add-hook 'agent-shell-mode-hook #'pro-agent-shell--setup-keys))
      (when (boundp 'agent-shell-hook)
        (add-hook 'agent-shell-hook #'pro-agent-shell--setup-keys))
      ;; На крайний случай — добавим advice на команду открытия, если она есть.
      (when (fboundp 'agent-shell)
        (defun pro-agent-shell--after-start (&rest _)
          "Re-apply setup keys after `agent-shell' starts. Defun form keeps
`advice-add' idempotent across `pro/reload-config' reloads."
          (pro-agent-shell--setup-keys))
        (advice-add #'agent-shell :after #'pro-agent-shell--after-start))

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
        "Return enriched project name (`proj:branch+wt:name').
Reads `.git/HEAD' directly, caches result by HEAD mtime. No fork/exec." 
        (let* ((root (or (and (fboundp 'pro-project-root) (pro-project-root))
                         default-directory))
               (dir (and root (directory-file-name (expand-file-name root))))
               (proj (and dir (file-name-nondirectory dir))))
          (when (and proj (not (string-empty-p proj)))
            (let* ((gitdir (pro-agent-shell--resolve-gitdir dir))
                   (head-path (and gitdir (expand-file-name "HEAD" gitdir)))
                   (mtime (and head-path
                               (file-attribute-modification-time
                                (file-attributes head-path))))
                   (key (cons dir mtime)))
              (if (and pro-agent-shell--project-name-cache
                       (equal (car pro-agent-shell--project-name-cache) key))
                  (cdr pro-agent-shell--project-name-cache)
                (let* ((worktree (and gitdir
                                      (string-match
                                       "/worktrees/\\([^/]+\\)/?\\'" gitdir)
                                      (match-string 1 gitdir)))
                       (branch (pro-agent-shell--branch-from-head
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
        (advice-add #'agent-shell--project-name :around #'pro-agent-shell--project-name-wrapper))

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
        (advice-add #'agent-shell--make-header :around #'pro-agent-shell--header-wrapper))

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
        (add-hook 'agent-shell-mode-hook #'pro-agent-shell--install-refresh-timer))
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

(provide 'pro-agent-shell)

;;; pro-agent-shell.el ends here
