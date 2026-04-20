;;; agent-shell.el --- Agent shell configuration -*- lexical-binding: t; -*-

;; Этот модуль настраивает agent-shell для интеграции с ИИ в ПРО-системе.

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
  (when (require 'agent-shell nil t)
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
    
    ;; Prefer the bundled agent config if available; avoid hard dependency on opencode.
    (setq agent-shell-preferred-agent-config 'gptel)
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

(provide 'agent-shell)
