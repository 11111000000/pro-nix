;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; pro-ai.el --- AI policy and entrypoint -*- lexical-binding: t; -*-

(require 'json)
(require 'seq)
(require 'subr-x)

(defun pro-ai--ensure-gptel-openai ()
  "Load gptel OpenAI backend support if available."
  (or (featurep 'gptel-openai)
      (require 'gptel-openai nil t)))

(defcustom pro-ai-backend 'aitunnel
  "Предпочтительный AI-backend."
  :type '(choice (const openrouter) (const siliconflow) (const aitunnel))
  :group 'pro-ui)

(defcustom pro-ai-enable-gptel-history t
  "Сохранять историю gptel-переписки."
  :type 'boolean
  :group 'pro-ui)

(defcustom pro-ai-auto-load-gptel t
  "Автоматически загружать gptel при старте Emacs, если пакет доступен."
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
  (format "%s" id))

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
    (when (and key host endpoint models
               (pro-ai--ensure-gptel-openai)
               (fboundp 'gptel-make-openai))
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

(defun pro-ai--backend-display-name (backend)
  "Вернуть читаемое имя BACKEND, если возможно."
  (cond
   ((and backend (fboundp 'gptel-backend-name))
    (condition-case nil
        (format "%s" (gptel-backend-name backend))
      (error (format "%s" backend))))
   (backend (format "%s" backend))
   (t "<nil>")))

(defun pro-ai--model-display-name (model)
  "Вернуть читаемое имя MODEL."
  (cond
   ((and model (fboundp 'gptel--model-name))
    (condition-case nil
        (format "%s" (gptel--model-name model))
      (error (format "%s" model))))
   (model (format "%s" model))
   (t "<nil>")))

(defun pro-ai--activate-backend (provider)
  "Сделать PROVIDER активным в gptel."
  (let ((backend-name (pro-ai--backend-name provider)))
    (pro-ai--ensure-gptel-openai)
    (when (and (fboundp 'gptel-get-backend)
               (gptel-get-backend backend-name))
      (setq gptel-backend (gptel-get-backend backend-name)
            gptel-model (pro-ai--select-model provider))
      t)))

(defun pro-ai-open-entry ()
  "Открыть AI-буфер с учётом выбранного backend-а."
  (interactive)
  (if (or (pro--package-provided-p 'gptel) (require 'gptel nil t))
      (progn
        ;; Ensure backends are registered when gptel is available.
        (pro-ai--ensure-backends)
        (pro-ai--activate-backend (pro-ai--backend-choice))
        (setq gptel-use-curl t
              gptel-track-response pro-ai-enable-gptel-history)
        (message "[pro-ai] active: backend=%s model=%s"
                 (pro-ai--backend-display-name (and (boundp 'gptel-backend) gptel-backend))
                 (pro-ai--model-display-name (and (boundp 'gptel-model) gptel-model)))
        ;; Be defensive when invoking gptel: it may be provided as an
        ;; interactive command or only as a callable function in some
        ;; deployments. Try the interactive path first, fall back to a
        ;; function call, otherwise warn once.
        (cond
         ((and (fboundp 'gptel) (commandp (symbol-function 'gptel)))
          (call-interactively #'gptel))
         ((fboundp 'gptel)
          (funcall (symbol-function 'gptel)))
         (t
          (pro-compat--notify-once "gptel" "gptel present but not callable"))))
    (pro-compat--notify-once "gptel" "gptel missing — AI entry unavailable")))

(defun pro-ai--gptel-runtime-available-p ()
  "Проверить, что gptel доступен в текущем runtime."
  (or (featurep 'gptel)
      (locate-library "gptel")))

(defun pro-ai--maybe-auto-load-gptel ()
  "Подключить gptel на старте, если пакет доступен и политика разрешает."
  (when (and pro-ai-auto-load-gptel
             (not (featurep 'gptel))
             (pro-ai--gptel-runtime-available-p))
    (require 'gptel nil t)))

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
  "Переключить AI-backend между тремя провайдерами."
  (interactive)
  (setq pro-ai-backend
        (pcase pro-ai-backend
          ('aitunnel 'openrouter)
          ('openrouter 'siliconflow)
          (_ 'aitunnel)))
  (message "[pro-ai] backend: %S" pro-ai-backend))

(defun pro-ai-reset-models ()
  "Сбросить кэш моделей и перечитать JSON."
  (interactive)
  (setq pro-ai--config-cache nil)
  (message "[pro-ai] models reloaded"))

(defun pro-ai-provider-name ()
  "Вернуть имя текущего AI-провайдера."
  (symbol-name (pro-ai--backend-choice)))

;; --- Carriage integration -------------------------------------------------
(defcustom pro-ai-carriage-path
  (expand-file-name "~/Code/carriage")
  "Каталог локального клона carriage (см. README в репозитории).
Если каталог присутствует, модуль попытается добавить его \"lisp\"-папку
в `load-path' и загрузить пакет carriage.
"
  :type 'directory
  :group 'pro-ui)

(defcustom pro-ai-enable-carriage t
  "Если non-nil, попытаться загрузить carriage из `pro-ai-carriage-path'."
  :type 'boolean
  :group 'pro-ui)

(defcustom pro-ai-carriage-enable-global-mode nil
  "Если non-nil — включать `carriage-global-mode' после загрузки carriage.
Оставьте nil по умолчанию: глобальный режим — опционален и может вмешиваться
в интерактивные сессии." :type 'boolean :group 'pro-ui)

(defun pro-ai--setup-carriage ()
  "Добавить carriage в `load-path' и применить базовые настройки из README.

Поведение:
- если `pro-ai-enable-carriage' и путь `pro-ai-carriage-path' существует —
  добавить папку "lisp" в `load-path' и попытаться `require`-нуть carriage;
- после загрузки установить `carriage-i18n-locale' в 'ru при наличии переменной;
- опционально включить `carriage-global-mode' если `pro-ai-carriage-enable-global-mode' true.
"
  (when (and pro-ai-enable-carriage
             (file-directory-p pro-ai-carriage-path))
    (let ((lisp (expand-file-name "lisp" pro-ai-carriage-path)))
      (when (file-directory-p lisp)
        (add-to-list 'load-path lisp)
        (condition-case _err
            (progn
              (require 'carriage nil t)
              (when (boundp 'carriage-i18n-locale)
                (setq carriage-i18n-locale 'ru))
              (when (and pro-ai-carriage-enable-global-mode
                         (fboundp 'carriage-global-mode))
                (carriage-global-mode 1))
              (message "[pro-ai] carriage loaded from %s" pro-ai-carriage-path))
          (error (message "[pro-ai] failed to load carriage from %s" lisp))))))

(pro-ai--setup-carriage)

;; Note: do not eagerly register backends here. Backends are registered when
;; `gptel' is loaded (see the `with-eval-after-load' block below) or on-demand
;; when the user opens the AI entry via `pro-ai-open-entry'. Eager registration
;; at load time can fail if gptel is not yet available on `load-path'.

;; Auto-activate default backend when gptel loads. Be defensive: some
;; gptel installations raise an error when asking for an unknown backend
;; name. Use condition-case to avoid aborting init if a backend is not
;; available.
(with-eval-after-load 'gptel
  (pro-ai--ensure-backends)
  (let ((backend
         (when (fboundp 'gptel-get-backend)
           (condition-case _err
               (gptel-get-backend "Aitunnel")
             (error nil)))))
    (when backend
      (setq gptel-backend backend
            gptel-model (pro-ai--select-model 'aitunnel)))
    (message "[pro-ai] default backend: %s"
             (pro-ai--backend-display-name backend))))

(if after-init-time
    (pro-ai--maybe-auto-load-gptel)
  (add-hook 'emacs-startup-hook #'pro-ai--maybe-auto-load-gptel))

(provide 'pro-ai)
;;; pro-ai.el ends here
