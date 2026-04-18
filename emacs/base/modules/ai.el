;;; ai.el --- AI policy and entrypoint -*- lexical-binding: t; -*-

;; Этот модуль задаёт минимальную политику AI: один вход, понятный выбор backend-а.

(defcustom pro-ai-backend 'openrouter
  "Предпочтительный AI-backend."
  :type '(choice (const openrouter) (const aitunnel))
  :group 'pro)

(defcustom pro-ai-openrouter-model nil
  "Модель по умолчанию для OpenRouter."
  :type '(choice (const nil) string)
  :group 'pro)

(defcustom pro-ai-aitunnel-model nil
  "Модель по умолчанию для AITunnel."
  :type '(choice (const nil) string)
  :group 'pro)

(defun pro-ai-open-entry ()
  "Открыть AI-буфер с учётом выбранного backend-а."
  (interactive)
  (when (require 'gptel nil t)
    (when (and (eq pro-ai-backend 'openrouter) pro-ai-openrouter-model)
      (setq gptel-model pro-ai-openrouter-model))
    (when (and (eq pro-ai-backend 'aitunnel) pro-ai-aitunnel-model)
      (setq gptel-model pro-ai-aitunnel-model))
    (gptel)))

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

(provide 'ai)
