;;; ai.el --- AI policy and entrypoint -*- lexical-binding: t; -*-

;; Этот модуль задаёт минимальную политику AI: один вход, понятный выбор backend-а.

(defcustom pro-ai-backend 'openrouter
  "Предпочтительный AI-backend."
  :type '(choice (const openrouter) (const aitunnel))
  :group 'pro-ui)

(defcustom pro-ai-enable-gptel-history t
  "Сохранять историю gptel-переписки."
  :type 'boolean
  :group 'pro-ui)

(defcustom pro-ai-openrouter-model nil
  "Модель по умолчанию для OpenRouter."
  :type '(choice (const nil) string)
  :group 'pro-ui)

(defcustom pro-ai-aitunnel-model nil
  "Модель по умолчанию для AITunnel."
  :type '(choice (const nil) string)
  :group 'pro-ui)

(defun pro-ai--resolve-model ()
  "Выбрать модель по текущему backend-у."
  (pcase pro-ai-backend
    ('openrouter pro-ai-openrouter-model)
    ('aitunnel pro-ai-aitunnel-model)
    (_ nil)))

(defun pro-ai-open-entry ()
  "Открыть AI-буфер с учётом выбранного backend-а."
  (interactive)
  (when (require 'gptel nil t)
    ;; Load API keys from ~/.authinfo if present (minimal helper below).
    (when (fboundp 'pro-ai-load-keys)
      (ignore-errors (pro-ai-load-keys)))

    (let ((model (pro-ai--resolve-model)))
      (when model
        (setq gptel-model model))
      (setq gptel-use-curl t
            gptel-track-response pro-ai-enable-gptel-history)
      (gptel))))


(defun pro-ai--load-key-from-authinfo (host user)
  "Load secret for HOST and USER from ~/.authinfo via auth-source.
Return the secret string or nil if missing. Lightweight helper used
to keep API keys out of the repository and loaded from the user's
authinfo file."
  (when (require 'auth-source nil t)
    (let ((auth (auth-source-search :max 1 :host host :user user)))
      (when auth
        (let ((secret (plist-get (car auth) :secret)))
          (if (functionp secret) (funcall secret) secret))))))

(defun pro-ai-load-keys ()
  "Load common AI provider keys from ~/.authinfo and export to env.
This keeps credentials out of the config. It is intentionally
minimal: it only exports a few environment variables commonly used
by providers and prints a short status message." 
  (interactive)
  (let ((openrouter (pro-ai--load-key-from-authinfo "openrouter.ai" "token"))
        (aitunnel (pro-ai--load-key-from-authinfo "api.aitunnel.ru" "token"))
        (openai (pro-ai--load-key-from-authinfo "api.openai.com" "openai")))
    (when openrouter (setenv "OPENROUTER_API_KEY" openrouter))
    (when aitunnel (setenv "AITUNNEL_KEY" aitunnel))
    (when openai (setenv "OPENAI_API_KEY" openai))
    (message "[pro-ai] keys: openrouter=%s aitunnel=%s openai=%s"
             (if openrouter "LOADED" "MISSING")
             (if aitunnel "LOADED" "MISSING")
             (if openai "LOADED" "MISSING"))))

(defun pro-ai-toggle-backend ()
  "Переключить AI-backend между OpenRouter и AITunnel."
  (interactive)
  (setq pro-ai-backend (if (eq pro-ai-backend 'openrouter) 'aitunnel 'openrouter))
  (message "[pro-ai] backend: %S" pro-ai-backend))

(defun pro-ai-reset-models ()
  "Сбросить локальные предпочтения моделей."
  (interactive)
  (setq pro-ai-openrouter-model nil
        pro-ai-aitunnel-model nil)
  (message "[pro-ai] models reset"))

(defun pro-ai-provider-name ()
  "Вернуть имя текущего AI-провайдера."
  (pcase pro-ai-backend
    ('openrouter "openrouter")
    ('aitunnel "aitunnel")
    (_ "unknown")))

;; Agent-shell integration
(with-eval-after-load 'agent-shell
  ;; Переименование буфера agent-shell для лучшей читаемости
  (defun pro-ai-agent-shell--pretty-buffer-name (name)
    "Return NAME with the agent-shell prefix shortened."
    (replace-regexp-in-string "\\`OpenCode Agent\\s-*" "🤖 " name))

  (defun pro-ai-agent-shell-rename-buffer ()
    "Normalize the initial agent-shell buffer name safely."
    (condition-case nil
        (when (and (derived-mode-p 'agent-shell-mode)
                   (string-prefix-p "OpenCode Agent" (buffer-name))
                   (boundp 'shell-maker-config)
                   shell-maker-config)
          (let ((short-name (pro-ai-agent-shell--pretty-buffer-name (buffer-name))))
            (rename-buffer short-name t)))
      (error nil)))

  ;; Добавляем hook для переименования буфера
  (add-hook 'agent-shell-mode-hook #'pro-ai-agent-shell-rename-buffer)

  ;; Оптимизация UI - предотвращаем повторную перезагрузку интерфейса
  (defvar-local pro-ai-agent-shell--ui-restored nil
    "Non-nil when agent-shell UI was already reasserted in this buffer.")

  (defun pro-ai-agent-shell--reload-after-first-turn (orig-fun &rest args)
    "Preserve visible agent-shell UI once, without rebuilding it repeatedly."
    (let ((result (apply orig-fun args)))
      (when (and (derived-mode-p 'agent-shell-mode)
                 (not pro-ai-agent-shell--ui-restored))
        (setq pro-ai-agent-shell--ui-restored t)
        (agent-shell-ui-mode +1)
        (agent-shell--update-header-and-mode-line))
      result))

  ;; Advice для оптимизации обработки
  (advice-add 'agent-shell--handle :around #'pro-ai-agent-shell--reload-after-first-turn))

(provide 'ai)
