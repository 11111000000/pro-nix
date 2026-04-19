;;; ai.el --- AI policy and entrypoint -*- lexical-binding: t; -*-

(require 'json)
(require 'seq)
(require 'subr-x)

(defcustom pro-ai-backend 'openrouter
  "Предпочтительный AI-backend."
  :type '(choice (const openrouter) (const siliconflow) (const aitunnel))
  :group 'pro-ui)

(defcustom pro-ai-enable-gptel-history t
  "Сохранять историю gptel-переписки."
  :type 'boolean
  :group 'pro-ui)

(defvar pro-ai--config-cache nil)
(defvar pro-ai--registered-backends nil)

(defun pro-ai--module-directory ()
  "Вернуть каталог системного модуля."
  (file-name-directory (or load-file-name buffer-file-name)))

(defcustom pro-ai-models-file
  (expand-file-name "ai-models.json" (pro-ai--module-directory))
  "Путь к базовому JSON-каталогу моделей."
  :type 'file
  :group 'pro-ui)

(defcustom pro-ai-user-models-file
  (expand-file-name "ai-models.json" user-emacs-directory)
  "Пользовательский JSON-каталог моделей."
  :type 'file
  :group 'pro-ui)

(defun pro-ai--read-json-file (path)
  "Прочитать JSON из PATH как alist."
  (when (file-readable-p path)
    (with-temp-buffer
      (insert-file-contents path)
      (let ((json-object-type 'alist)
            (json-array-type 'list)
            (json-key-type 'symbol)
            (json-false nil))
        (json-read)))))

(defun pro-ai--merge-plists (base override)
  "Поверхностно слить BASE и OVERRIDE."
  (let ((result (copy-sequence base)))
    (while override
      (setq result (plist-put result (pop override) (pop override))))
    result))

(defun pro-ai--normalize-model-id (id)
  "Нормализовать ID модели к строке для gptel."
  (replace-regexp-in-string "^\|$" "" (format "%s" id)))

(defun pro-ai--merge-provider-configs (base override)
  "Слить конфиги провайдеров BASE и OVERRIDE по имени."
  (let* ((base-providers (alist-get 'providers base))
         (override-providers (alist-get 'providers override))
         (merged-providers
          (append override-providers
                  (seq-remove (lambda (entry)
                                (assoc (car entry) override-providers))
                              base-providers))))
    `((providers . ,merged-providers))))

(defun pro-ai--config ()
  "Вернуть объединённый JSON-конфиг провайдеров."
  (or pro-ai--config-cache
      (setq pro-ai--config-cache
            (let ((base (pro-ai--read-json-file pro-ai-models-file))
                  (user (pro-ai--read-json-file pro-ai-user-models-file)))
              (cond
               ((and base user) (pro-ai--merge-provider-configs base user))
               (user user)
               (base base)
               (t nil))))))

(defun pro-ai--provider-config (name)
  "Вернуть конфиг провайдера NAME."
  (alist-get name (alist-get 'providers (pro-ai--config))))

(defun pro-ai--provider-field (provider field)
  "Вернуть FIELD провайдера PROVIDER."
  (alist-get field provider))

(defun pro-ai--provider-models (provider)
  "Вернуть список моделей для PROVIDER."
  (mapcar #'pro-ai--normalize-model-id (alist-get 'models provider)))

(defun pro-ai--load-key-from-authinfo (host user)
  "Загрузить секрет для HOST и USER из authinfo."
  (when (and (or (file-exists-p (expand-file-name "~/.authinfo"))
                 (file-exists-p (expand-file-name "~/.authinfo.gpg")))
             (require 'auth-source nil t))
    (condition-case nil
        (let ((auth (auth-source-search :max 1 :host host :user user)))
          (when auth
            (let ((secret (plist-get (car auth) :secret)))
              (cond
               ((functionp secret)
                (let ((value (ignore-errors (funcall secret))))
                  (and (stringp value) (not (string-empty-p value)) value)))
               ((stringp secret)
                (and (not (string-empty-p secret)) secret))))))
      (error nil))))

(defun pro-ai--backend-name (provider)
  "Имя gptel-backend для PROVIDER."
  (capitalize (symbol-name provider)))

(defun pro-ai--host-from-provider (provider)
  "Вернуть host для PROVIDER по его имени."
  (pcase provider
    ('openrouter "openrouter.ai")
    ('siliconflow "api.siliconflow.com")
    ('aitunnel "api.aitunnel.ru")
    (_ nil)))

(defun pro-ai--register-backend (provider)
  "Зарегистрировать backend для PROVIDER."
  (let* ((config (pro-ai--provider-config provider))
         (backend-name (pro-ai--backend-name provider))
         (host (or (pro-ai--provider-field config 'host)
                   (pro-ai--host-from-provider provider)))
         (endpoint (pro-ai--provider-field config 'endpoint))
         (auth-host (or (pro-ai--provider-field config 'auth_host) host))
         (auth-user (or (pro-ai--provider-field config 'auth_user) "token"))
         (key (pro-ai--load-key-from-authinfo auth-host auth-user))
         (models (pro-ai--provider-models config)))
    (when (and key host endpoint models (fboundp 'gptel-make-openai))
      (setq gptel--known-backends
            (assq-delete-all backend-name gptel--known-backends))
      (gptel-make-openai backend-name
        :host host
        :endpoint endpoint
        :key key
        :models models)
      (push backend-name pro-ai--registered-backends)
      backend-name)))

(defun pro-ai--ensure-backends ()
  "Зарегистрировать все поддерживаемые backend-и."
  (setq pro-ai--registered-backends nil)
  (dolist (provider '(openrouter siliconflow aitunnel))
    (pro-ai--register-backend provider)))

(defun pro-ai--backend-choice ()
  "Вернуть текущий backend с fallback."
  (or pro-ai-backend 'openrouter))

(defun pro-ai--select-model (provider)
  "Вернуть модель для PROVIDER из конфига."
  (let* ((config (pro-ai--provider-config provider))
         (preferred (alist-get 'preferred_model config))
         (models (pro-ai--provider-models config)))
    (or preferred (car models))))

(defun pro-ai--activate-backend (provider)
  "Сделать PROVIDER активным в gptel."
  (let ((backend-name (pro-ai--backend-name provider)))
    (when (and (fboundp 'gptel-get-backend)
               (gptel-get-backend backend-name))
      (setq gptel-backend (gptel-get-backend backend-name)
            gptel-model (pro-ai--select-model provider))
      t)))

(defun pro-ai-open-entry ()
  "Открыть AI-буфер с учётом выбранного backend-а."
  (interactive)
  (when (require 'gptel nil t)
    (pro-ai--ensure-backends)
    (unless (pro-ai--activate-backend (pro-ai--backend-choice))
      (catch 'pro-ai-found
        (dolist (provider '(openrouter siliconflow aitunnel))
          (when (pro-ai--activate-backend provider)
            (setq pro-ai-backend provider)
            (throw 'pro-ai-found t)))))
    (setq gptel-use-curl t
          gptel-track-response pro-ai-enable-gptel-history)
    (call-interactively #'gptel)))

(defun pro-ai-toggle-backend ()
  "Переключить AI-backend между тремя провайдерами."
  (interactive)
  (setq pro-ai-backend
        (pcase pro-ai-backend
          ('openrouter 'siliconflow)
          ('siliconflow 'aitunnel)
          (_ 'openrouter)))
  (message "[pro-ai] backend: %S" pro-ai-backend))

(defun pro-ai-reset-models ()
  "Сбросить кэш моделей и перечитать JSON."
  (interactive)
  (setq pro-ai--config-cache nil)
  (message "[pro-ai] models reloaded"))

(defun pro-ai-provider-name ()
  "Вернуть имя текущего AI-провайдера."
  (symbol-name (pro-ai--backend-choice)))

(pro-ai--ensure-backends)

(provide 'ai)
