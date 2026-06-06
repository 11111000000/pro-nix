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
  (require 'agent-shell nil t))

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
        "Установить локальные клавиши в буфере agent-shell, если режим доступен."
        (when (derived-mode-p 'agent-shell-mode)
          (when (fboundp 'agent-shell-set-session-model)
            (local-set-key (kbd "C-c m") #'agent-shell-set-session-model))))

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
      (defun pro-agent-shell--project-name ()
        "Return current project name, with branch and worktree info if available.

Uses `pro-project-root' when available, otherwise falls back to
`default-directory'. The returned string is concise, e.g. \"proj:main\" or
\"proj:feature/foo+wt:adoring-hawking\" when in a git worktree." 
        (let* ((root (if (and (fboundp 'pro-project-root)
                              (pro-project-root))
                          (pro-project-root)
                        default-directory))
               (dir (and root (directory-file-name (expand-file-name root))))
               (proj (file-name-nondirectory (or dir ""))))
          (when proj
            (condition-case _err
                (let* ((default-directory (or dir default-directory))
                       (branch (string-trim (shell-command-to-string "git rev-parse --abbrev-ref HEAD 2>/dev/null")))
                       (gitdir-out (string-trim (shell-command-to-string "git rev-parse --git-dir 2>/dev/null")))
                       (gitdir (and (not (string-empty-p gitdir-out))
                                    ;; Make absolute and normalize
                                    (expand-file-name gitdir-out default-directory)))
                       (worktree-name (when (and gitdir (string-match "/worktrees/\\([^/]+\\)$" gitdir))
                                        (match-string 1 gitdir))))
                  (if (not (string-empty-p branch))
                      (if worktree-name
                          (format "%s:%s+wt:%s" proj branch worktree-name)
                        (format "%s:%s" proj branch))
                    proj))
              (error proj)))))

      (when (fboundp 'agent-shell--project-name)
        (defun pro-agent-shell--project-name-wrapper (orig-fn)
          "Return project name enriched with branch and worktree info."
          (let ((base (funcall orig-fn)))
            (if (and base (not (string-empty-p base)))
                (let* ((dir default-directory)
                       (enriched (let ((default-directory dir))
                                   (pro-agent-shell--project-name))))
                  (if (and enriched (not (string-empty-p enriched)))
                      enriched
                    base))
              base)))
        (advice-add #'agent-shell--project-name :override #'pro-agent-shell--project-name-wrapper))

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
      (defun pro-agent-shell--refresh-timer-fn ()
        "Timer callback: re-render the agent-shell header in the current buffer."
        (when (derived-mode-p 'agent-shell-mode)
          (ignore-errors (agent-shell--update-header-and-mode-line))))

      (defun pro-agent-shell--install-refresh-timer ()
        "Install a buffer-local timer that re-renders the header every 5s."
        (when (and (derived-mode-p 'agent-shell-mode)
                   (fboundp 'agent-shell--update-header-and-mode-line)
                   (not (timerp pro-agent-shell--refresh-timer)))
          (setq pro-agent-shell--refresh-timer
                (run-at-time 5 5 #'pro-agent-shell--refresh-timer-fn))))

      (defvar-local pro-agent-shell--refresh-timer nil
        "Buffer-local timer that re-renders the agent-shell header.")

      (defun pro-agent-shell--cancel-refresh-timer ()
        "Cancel the agent-shell header refresh timer in the current buffer."
        (when (timerp pro-agent-shell--refresh-timer)
          (cancel-timer pro-agent-shell--refresh-timer)
          (setq pro-agent-shell--refresh-timer nil)))

      (when (boundp 'agent-shell-mode-hook)
        (add-hook 'agent-shell-mode-hook #'pro-agent-shell--install-refresh-timer))
      (add-hook 'kill-buffer-hook #'pro-agent-shell--cancel-refresh-timer nil t))
  (error (message "[pro-agent-shell] agent-shell integration skipped: %S" err)))

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
