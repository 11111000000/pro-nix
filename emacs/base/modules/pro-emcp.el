;;; pro-emcp.el --- EMCP HTTP-сервер для внешних MCP-клиентов (pi, opencode) -*- lexical-binding: t; -*-
;; Назначение: поднять EMCP-сервер на фиксированном порту 127.0.0.1:38913
;; сразу после init, чтобы любой MCP-клиент мог подключиться по стабильному
;; URL `http://127.0.0.1:38913/mcp`. Агент-shell использует свой механизм
;; (см. pro-agent-shell.el) и подхватывает уже запущенный сервер, если
;; профиль совпадает.
;;
;; Правила:
;;  - Модуль всегда синтаксически корректен и безопасен в окружении без
;;    пакета `emcp' (CI, headless-тесты, минимальные контейнеры).
;;  - В batch-режиме (`noninteractive' = t) не пытаемся стартовать сервер.
;;  - Идемпотентность на reload обеспечивается самим `emcp-start': повторный
;;    вызов для того же профиля возвращает существующий сервер, не плодит
;;    новые процессы.
;;
;; Публичная поверхность:
;;  - pro-emcp-server-port        ; integer, default 38913
;;  - pro-emcp-server-host        ; string,  default "127.0.0.1"
;;  - pro-emcp-server-profile     ; symbol, default 'full-control
;;  - pro-emcp-server-auto-start  ; boolean, default t
;;  - M-x pro-emcp-server-start   ; запустить сервер
;;  - M-x pro-emcp-server-stop    ; остановить сервер
;;  - M-x pro-emcp-server-restart ; перезапустить
;;  - M-x pro-emcp-server-status  ; показать URL или "не запущен"
;;  - (pro-emcp-server-url)       ; URL или nil (программный интерфейс)
;;
;; Профили EMCP (см. submodules/emcp/README.org):
;;  - inspect       ; apropos, describe, find-definition, find-references,
;;                  ; info-search, info:// resource, /screenshot prompt
;;  - develop       ; + get-variable, set-variable, screenshot
;;  - full-control  ; + eval (gated), send-keys (gated)
;;                  ; Дефолт: нужен eval/send-keys "из коробки" для pi/opencode.
;;                  ; Каждый вызов eval/send-keys всё равно проходит через
;;                  ; `*EMCP confirm*' с дефолтной политикой 'ask' — отключить
;;                  ; гейт можно только явно (см. `emcp-tools-eval-default-policy'
;;                  ; / `emcp-tools-send-keys-default-policy', или session-mode
;;                  ; `a' в буфере подтверждения).

;; ---------------------------------------------------------------------------
;; Декларации для byte-compiler
;; ---------------------------------------------------------------------------
;; Эти переменные и функции определены в `emcp' (submodules/emcp/) и не
;; видны на этапе компиляции этого модуля — модуль должен оставаться
;; загружаемым в окружении без `emcp' (CI, headless). `defvar' с
;; `ignore' гасит "free variable" warning; `declare-function' делает то же
;; для функций.

(defvar emcp-http-port)
(defvar emcp-http-host)
(defvar emcp-default-profile)
(defvar emcp--servers)
(declare-function emcp-start "emcp" (profile))
(declare-function emcp-stop "emcp" (profile))
(declare-function emcp-server-url "emcp" (server))

;; ---------------------------------------------------------------------------
;; Опции
;; ---------------------------------------------------------------------------

(defgroup pro-emcp nil
  "EMCP HTTP-сервер для внешних MCP-клиентов."
  :group 'pro
  :prefix "pro-emcp-server-")

(defcustom pro-emcp-server-port 38913
  "Фиксированный TCP-порт для EMCP HTTP-сервера.

MCP-клиенты (pi, opencode) настроены на `http://127.0.0.1:<port>/mcp`.
Меняйте здесь, если порт занят — синхронно обновите
`local-templates/pi/mcp.json` и `local-templates/opencode/opencode.json`."
  :type 'integer
  :group 'pro-emcp)

(defcustom pro-emcp-server-host "127.0.0.1"
  "Хост для EMCP HTTP-сервера. По умолчанию loopback — снаружи не виден."
  :type 'string
  :group 'pro-emcp)

(defcustom pro-emcp-server-profile 'full-control
  "Профиль EMCP, который стартует автоматически.

`full-control' = inspect + develop + eval + send-keys. `eval' и
`send-keys' гейтнуты политикой `emcp-tools-eval-default-policy' /
`emcp-tools-send-keys-default-policy' (по умолчанию `ask' — каждый
вызов требует подтверждения в буфере `*EMCP confirm*').

Чтобы вернуться к `develop' (только inspect/get-variable/set-variable/
screenshot) — `M-x customize-variable RET pro-emcp-server-profile RET'
или в `~/.config/emacs/modules/<user>.el':
  (setq pro-emcp-server-profile 'develop)
и затем `M-x pro/reload-config'."
  :type '(choice (const inspect) (const develop) (const full-control))
  :group 'pro-emcp)

(defcustom pro-emcp-server-auto-start t
  "Если non-nil, сервер стартует автоматически на `after-init-hook'."
  :type 'boolean
  :group 'pro-emcp)

;; ---------------------------------------------------------------------------
;; Внутренние помощники
;; ---------------------------------------------------------------------------

(defun pro-emcp--ensure-loaded ()
  "Загрузить `emcp' если пакет доступен в runtime. Вернуть non-nil при успехе."
  (or (featurep 'emcp) (require 'emcp nil t)))

(defun pro-emcp--apply-config ()
  "Применить наши настройки к кастомам `emcp'. Требует загруженный `emcp'."
  (when (pro-emcp--ensure-loaded)
    ;; Customs определены в emcp.el/emcp-http.el и валидны только после
    ;; require — поэтому читаем defvar-имена напрямую через symbol-value,
    ;; а не объявляем их defvar здесь (иначе получим дубликат-предупреждение).
    (setq emcp-http-port pro-emcp-server-port
          emcp-http-host pro-emcp-server-host
          emcp-default-profile pro-emcp-server-profile)
    t))

;; ---------------------------------------------------------------------------
;; Публичные команды
;; ---------------------------------------------------------------------------

(defun pro-emcp-server-start ()
  "Запустить EMCP HTTP-сервер для `pro-emcp-server-profile'.
URL кладётся в kill-ring и показывается в `*Messages*'."
  (interactive)
  (if (pro-emcp--ensure-loaded)
      (progn
        (pro-emcp--apply-config)
        (let* ((server (condition-case err
                           (emcp-start pro-emcp-server-profile)
                         (error (progn
                                  (message "[pro-emcp] emcp-start failed: %S" err)
                                  nil))))
               (url (and server (ignore-errors (emcp-server-url server)))))
          (cond
           ((and url (called-interactively-p 'any))
            (kill-new url)
            (message "emcp server [%s] running at %s (in kill-ring)"
                     pro-emcp-server-profile url)
            url)
           (url url)
           (t (message "[pro-emcp] не удалось запустить emcp-сервер. Проверьте *Messages*")
              nil))))
    (message "[pro-emcp] пакет `emcp' не найден в runtime (pro-packages-provided-by-nix не включает его — пересоберите Emacs-профиль через home-manager)")))

(defun pro-emcp-server-stop ()
  "Остановить EMCP HTTP-сервер для `pro-emcp-server-profile'."
  (interactive)
  (if (pro-emcp--ensure-loaded)
      (condition-case err
          (progn
            (emcp-stop pro-emcp-server-profile)
            (message "emcp server [%s] stopped" pro-emcp-server-profile))
        (error (message "[pro-emcp] emcp-stop failed: %S" err)))
    (message "[pro-emcp] пакет `emcp' не найден в runtime")))

(defun pro-emcp-server-restart ()
  "Перезапустить EMCP HTTP-сервер для `pro-emcp-server-profile'."
  (interactive)
  (when (pro-emcp--ensure-loaded)
    (ignore-errors (emcp-stop pro-emcp-server-profile)))
  (pro-emcp-server-start))

(defun pro-emcp-server-status ()
  "Показать статус EMCP-сервера в `*Messages*'."
  (interactive)
  (if (pro-emcp--ensure-loaded)
      (let ((server (alist-get pro-emcp-server-profile emcp--servers)))
        (if server
            (message "emcp server [%s] running at %s"
                     pro-emcp-server-profile
                     (ignore-errors (emcp-server-url server)))
          (message "emcp server [%s] not running. M-x pro-emcp-server-start"
                   pro-emcp-server-profile)))
    (message "[pro-emcp] пакет `emcp' не найден в runtime")))

(defun pro-emcp-server-url ()
  "Вернуть URL запущенного EMCP-сервера для `pro-emcp-server-profile', или nil."
  (when (pro-emcp--ensure-loaded)
    (let ((server (alist-get pro-emcp-server-profile emcp--servers)))
      (and server (ignore-errors (emcp-server-url server))))))

;; ---------------------------------------------------------------------------
;; Автозапуск на after-init-hook
;; ---------------------------------------------------------------------------

(defun pro-emcp--auto-start-fn ()
  "Запустить EMCP-сервер после init. Тихий режим — ошибки только в `*Messages*'."
  (when (and pro-emcp-server-auto-start
             (not noninteractive)
             (pro-emcp--ensure-loaded))
    (condition-case err
        (let ((url (pro-emcp-server-start)))
          (when url
            (message "[pro-emcp] server running at %s (MCP clients: pi/opencode)" url)))
      (error (message "[pro-emcp] auto-start failed: %S" err)))))

(add-hook 'after-init-hook #'pro-emcp--auto-start-fn)

(provide 'pro-emcp)

;;; pro-emcp.el ends here
