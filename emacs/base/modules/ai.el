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
    (let ((model (pro-ai--resolve-model)))
      (when model
        (setq gptel-model model))
      (setq gptel-use-curl t
            gptel-track-response pro-ai-enable-gptel-history)
      (gptel))))

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

(provide 'ai)
