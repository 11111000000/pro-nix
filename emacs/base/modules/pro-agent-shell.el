;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; pro-agent-shell.el --- Agent shell configuration -*- lexical-binding: t; -*-

;; Этот модуль настраивает agent-shell для интеграции с ИИ в ПРО-системе.
;;
;; Контракт файла:
;; - Название: emacs/base/modules/pro-agent-shell.el — agent-shell настройки
;; - Цель: настроить удобные дефолты и политики запуска для agent-shell, совместимые с Nix-окружением.
;; - Контракт: экспортирует функцию pro-agent-shell-setup и настаивает на idempotent-инициализации.
;; - Побочные эффекты: установка переменных окружения, регистрация путей транскриптов и keybindings.
;; - Proof: emacs/base/tests/* (headless ERT) и ручные smoke-тесты через ./scripts/emacs-pro-wrapper.sh
;; - Last reviewed: 2026-05-02


(defcustom pro-agent-shell-enable-ui-optimization t
  "Включить оптимизацию UI agent-shell."
  :type 'boolean
  :group 'pro-ai)

(defcustom pro-agent-shell-buffer-prefix "🤖 "
  "Префикс для буферов agent-shell."
  :type 'string
  :group 'pro-ai)

(defun pro-agent-shell-setup ()
  "Настроить agent-shell с оптимизациями для ПРО."
  (when (or (pro--package-provided-p 'agent-shell) (pro-packages--maybe-install 'agent-shell t) (require 'agent-shell nil t))
    ;; Базовые настройки UI
    (setq agent-shell-header-style 'text)
    (setq agent-shell-show-config-icons t)
    (setq agent-shell-show-session-id nil)
    (setq agent-shell-show-welcome-message t)
    (setq agent-shell-show-busy-indicator nil)
    (setq agent-shell-section-functions nil)
    (setq agent-shell-show-context-usage-indicator nil)
    (setq agent-shell-show-usage-at-turn-end t)
    (setq agent-shell-thought-process-expand-by-default nil)
    (setq agent-shell-tool-use-expand-by-default nil)
    (setq agent-shell-user-message-expand-by-default nil)
    (setq agent-shell-prefer-viewport-interaction nil)
    (setq agent-shell-highlight-blocks nil)
    (setq agent-shell-confirm-interrupt nil)
    (setq agent-shell-prefer-session-resume t)
    (setq agent-shell-embed-file-size-limit 102400)
    (setq shell-maker-logging nil)
    
    ;; Настройка пути для транскриптов
    (setq agent-shell-transcript-file-path-function
          (lambda ()
            (expand-file-name
             (format-time-string "%F-%H-%M-%S.md")
             (agent-shell--dot-subdir "transcripts"))))
    
    ;; Prefer the opencode agent config by default (OpenCode CLI).
    ;; This makes the agent-shell "OpenCode" option the primary choice.
    ;; If your environment should prefer the reproducible Nix store binary
    ;; rather than a user-local cached binary or the wrapper's bootstrap,
    ;; set `pro-agent-shell-opencode-use-store' to non-nil so Emacs exports
    ;; OPENCODE_USE_STORE=1 before starting processes.
    (defcustom pro-agent-shell-opencode-use-store nil
      "If non-nil, export OPENCODE_USE_STORE=1 in Emacs so the opencode
wrapper prefers the Nix store binary when launched from Emacs.
This can help avoid wrapper behavior that runs the binary under
systemd-run/steam-run which sometimes interferes with agent-shell IO." 
      :type 'boolean
      :group 'pro-ai)

    (when pro-agent-shell-opencode-use-store
      (setenv "OPENCODE_USE_STORE" "1")
      (message "[pro-agent-shell] OPENCODE_USE_STORE=1 exported for opencode-launches"))

    ;; Prefer the opencode agent config and try to use the Nix store
    ;; binary directly when available. The system wrapper `opencode` in
    ;; this repo may exec the real binary under `systemd-run` or
    ;; `steam-run`, which breaks ACP (it detaches stdio). To avoid that,
    ;; prefer a direct Nix store path if present.
    (defun pro-agent-shell--nix-store-opencode-path ()
      "Return a probable Nix store opencode binary path or nil.

Search order:
- OPENCODE_STORE_PATH env var (if set)
- first candidate under /nix/store/*opencode*/bin/opencode
"
      (or (when (getenv "OPENCODE_STORE_PATH")
            (let ((p (expand-file-name "bin/opencode" (getenv "OPENCODE_STORE_PATH"))))
              (and (file-executable-p p) p)))
          (let ((cands (cl-remove-if-not
                        #'file-executable-p
                        (mapcar (lambda (p) (expand-file-name "bin/opencode" p))
                                (ignore-errors (directory-files "/nix/store" t "opencode"))))))
            (car cands))))

    (when (boundp 'agent-shell-opencode-acp-command)
      (let ((store-bin (pro-agent-shell--nix-store-opencode-path)))
        (when store-bin
          (setq agent-shell-opencode-acp-command (list store-bin "acp"))
          (message "[pro-agent-shell] using opencode from Nix store: %s" store-bin))))

    (setq agent-shell-preferred-agent-config 'opencode)
    (setq agent-shell-session-strategy 'prompt)))

;; Инициализация настроек
(pro-agent-shell-setup)

;; Keybindings: mirror pro config for ergonomic interaction
(with-eval-after-load 'agent-shell
  (when (boundp 'agent-shell-mode-map)
    (let ((map agent-shell-mode-map))
      (when (keymapp map)
        (define-key map (kbd "C-<return>") #'newline)
        (define-key map (kbd "M-<return>") #'newline)
        (when (fboundp 'shell-maker-submit)
          (define-key map (kbd "RET") #'shell-maker-submit))
        ;; Disable default C-g to avoid accidental quit; use C-c C-g to interrupt
        (define-key map (kbd "C-g") nil)
        (when (fboundp 'agent-shell-interrupt)
          (define-key map (kbd "C-c C-g") #'agent-shell-interrupt))
        (when (fboundp 'agent-shell-show-usage)
          (define-key map (kbd "C-c C-u") #'agent-shell-show-usage))))))

(provide 'pro-agent-shell)
