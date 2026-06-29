;;; pro-ai-anvil.el --- anvil.el: MCP-сервер в Elisp для внешних агентов -*- lexical-binding: t; -*-
;;
;; Назначение: тонкая обвязка над anvil.el (https://github.com/zawatton/anvil.el).
;; Anvil — это MCP-сервер, написанный на Elisp: ~40 default tools (file / org /
;; elisp / sqlite) + опциональные модули (memory / orchestrator / semantic /
;; mu4e / cad / fusion). Pi и opencode подключаются к нему через stdio MCP.
;;
;; Правила:
;;   - Модуль остаётся синтаксически корректным в окружении без anvil.
;;     Все публичные команды проверяют `pro-ai-anvil--available-p'.
;;   - Авто-запуск сервера — ТОЛЬКО по `pro-ai-anvil-auto-start' (default nil).
;;     Anvil запускает долгоживущий stdio-loop; включать его без явной
;;     причины — лишний расход памяти. Пользовательский workflows:
;;       M-x pro-ai-anvil-server-start
;;       ; или: emacsclient -e '(pro-ai-anvil-server-start)'
;;   - `pro-ai-anvil--describe-setup' возвращает JSON-фрагмент для вставки
;;     в local-templates/{pi,opencode}/mcp.json — единый источник истины
;;     для регистрации MCP-сервера.
;;   - anvil требует `cl-lib', `transient', `posframe' и собственные
;;     `anvil-*' модули. Все они зашиты в recipe nix/emacs-recipes/anvil.nix.
;;
;; Публичная поверхность:
;;   - `pro-ai-anvil-server-start'  ; запустить anvil-enable + anvil-server-start
;;   - `pro-ai-anvil-server-stop'   ; остановить anvil
;;   - `pro-ai-anvil-server-status' ; напечатать состояние
;;   - `pro-ai-anvil-describe-setup' ; напечатать JSON для pi/opencode mcp.json
;;   - `pro-ai-anvil-list-tools'    ; перечислить активные anvil-* tools
;;
;; Зависимости:
;;   - anvil (nix/emacs-recipes/anvil.nix)
;;
;; См. также:
;;   - pro-ai.el          ; gptel entry point
;;   - pro-ai-ellama.el   ; AGENTS-aware LLM-клиент в Emacs
;;   - pro-emcp.el        ; HTTP MCP-сервер (стабильный URL)
;;   - local-templates/pi/mcp.json
;;   - local-templates/opencode/opencode.json
;;   - docs/agent-configs.md

(require 'cl-lib)
(require 'subr-x)
(require 'json)
(require 'pro-compat)

(defgroup pro-ai-anvil nil
  "anvil.el — MCP-сервер в Elisp (file / org / elisp / sqlite)."
  :group 'pro-ai
  :prefix "pro-ai-anvil-")

;; --- Опции ---------------------------------------------------------------

(defcustom pro-ai-anvil-auto-start nil
  "Если non-nil, запускать anvil-server при `after-init-hook'.
По умолчанию nil — anvil тяжёлый и стартует по явному запросу.
Включите в `custom.el', если MCP-сервер нужен постоянно."
  :type 'boolean
  :group 'pro-ai-anvil)

(defcustom pro-ai-anvil-profile 'default
  "Профиль модулей anvil.el, которые нужно подгрузить.

Возможные значения:
  - `default'   — `anvil-enable' без opt-in модулей: file / org / elisp /
                  sqlite / shell (~40 tools).
  - `semantic'  — добавить `anvil-semantic' (FTS5 + optional vector
                  embeddings). Требует sqlite и ~50 MB на ollama.
  - `full'      — default + memory + orchestrator + mu4e + cad. Осторожно:
                  memory пишет в SQLite, orchestrator стартует fan-out
                  на 5 LLM-CLI параллельно.
  - nil         — НЕ вызывать `anvil-enable'; пользователь настроит руками."
  :type '(choice (const :tag "Default (~40 tools)" default)
                 (const :tag "Semantic search" semantic)
                 (const :tag "Full (memory + orchestrator + …)" full)
                 (const :tag "Do not auto-enable" nil))
  :group 'pro-ai-anvil)

(defcustom pro-ai-anvil-mcp-server-port 38913
  "Порт для отладочного HTTP MCP-сервера anvil (если включён).
Anvil по умолчанию говорит по stdio. Этот порт нужен только когда
вы хотите curl-ом посмотреть, что вообще отвечает anvil. Не путать
с `pro-emcp-server-port' — это разные серверы."
  :type 'integer
  :group 'pro-ai-anvil)

;; --- Доступность --------------------------------------------------------

(defun pro-ai-anvil--available-p ()
  "Не-p если пакет `anvil' доступен в runtime."
  (or (featurep 'anvil) (require 'anvil nil t)))

;; --- Setup --------------------------------------------------------------

(defvar pro-ai-anvil--setup-done nil
  "Non-nil если `pro-ai-anvil--apply-setup' уже отработал.")

(defun pro-ai-anvil--apply-setup ()
  "Применить выбранный `pro-ai-anvil-profile'. Идемпотентно."
  (when (and (pro-ai-anvil--available-p)
             (not pro-ai-anvil--setup-done))
    (pcase pro-ai-anvil-profile
      ('default
       (condition-case err
           (progn
             (require 'anvil)
             (anvil-enable))
         (error (message "[pro-ai-anvil] anvil-enable failed: %S" err))))
      ('semantic
       (condition-case err
           (progn
             (require 'anvil)
             (require 'anvil-semantic)
             (anvil-enable))
         (error (message "[pro-ai-anvil] anvil-enable (semantic) failed: %S" err))))
      ('full
       (condition-case err
           (progn
             (require 'anvil)
             (require 'anvil-semantic)
             (require 'anvil-memory)
             (require 'anvil-orchestrator)
             (anvil-enable))
         (error (message "[pro-ai-anvil] anvil-enable (full) failed: %S" err))))
      (_ nil))
    (setq pro-ai-anvil--setup-done t)
    (message "[pro-ai-anvil] profile=%s applied" pro-ai-anvil-profile)))

;; --- Команды ------------------------------------------------------------

(defun pro-ai-anvil-server-start ()
  "Запустить anvil-enable и anvil-server-start.
Безопасный entry point. Идемпотентно: повторный вызов не плодит серверы."
  (interactive)
  (if (pro-ai-anvil--available-p)
      (progn
        (pro-ai-anvil--apply-setup)
        (condition-case err
            (progn
              (require 'anvil-server)
              (call-interactively #'anvil-server-start)
              (message "[pro-ai-anvil] server running (stdio MCP); profile=%s"
                       pro-ai-anvil-profile))
          (error (message "[pro-ai-anvil] anvil-server-start failed: %S" err))))
    (message "[pro-ai-anvil] пакет `anvil' не найден. Пересоберите Emacs-профиль через `just switch' (anvil в `modules/pro-users-nixos.nix`).")))

(defun pro-ai-anvil-server-stop ()
  "Остановить anvil-server, если запущен."
  (interactive)
  (if (pro-ai-anvil--available-p)
      (condition-case err
          (progn
            (require 'anvil-server)
            (when (fboundp 'anvil-server-stop)
              (call-interactively #'anvil-server-stop)
              (message "[pro-ai-anvil] server stopped"))
            (when (fboundp 'anvil-disable)
              (anvil-disable))
            (setq pro-ai-anvil--setup-done nil))
        (error (message "[pro-ai-anvil] stop failed: %S" err)))
    (message "[pro-ai-anvil] пакет `anvil' не найден")))

(defun pro-ai-anvil-server-status ()
  "Напечатать статус anvil-сервера в `*Messages*'."
  (interactive)
  (cond
   ((not (pro-ai-anvil--available-p))
    (message "[pro-ai-anvil] пакет `anvil' не найден"))
   ((and (fboundp 'anvil-server-running-p)
         (anvil-server-running-p))
    (message "[pro-ai-anvil] server running (stdio); profile=%s setup=%s"
             pro-ai-anvil-profile pro-ai-anvil--setup-done))
   (t
    (message "[pro-ai-anvil] server not running. M-x pro-ai-anvil-server-start"))))

(defun pro-ai-anvil-list-tools ()
  "Перечислить активные anvil-* tools. Полезно для отладки MCP-сессии."
  (interactive)
  (if (pro-ai-anvil--available-p)
      (let ((tools nil))
        (mapatoms
         (lambda (sym)
           (let ((name (symbol-name sym)))
             (when (and (string-prefix-p "anvil-" name)
                        (fboundp sym)
                        (string-match-p "-\\(tool\\|handler\\|action\\)-" name))
               (push name tools)))))
        (setq tools (sort tools #'string<))
        (with-output-to-temp-buffer "*pro-ai-anvil-tools*"
          (princ "Active anvil tools:\n\n")
          (dolist (tool tools) (princ (format "  %s\n" tool))))
        (message "[pro-ai-anvil] %d anvil tools" (length tools)))
    (message "[pro-ai-anvil] пакет `anvil' не найден")))

;; --- Setup snippet (для local-templates) --------------------------------

(defun pro-ai-anvil-describe-setup ()
  "Напечатать JSON-фрагмент для вставки в pi/opencode mcp.json.
Кладёт в kill-ring и в буфер `*pro-ai-anvil-setup*'."
  (interactive)
  (let* ((emacs-bin (or (and (boundp 'invocation-directory)
                             (expand-file-name "emacs" invocation-directory))
                        "emacs"))
         (snippet
          (list :mcpServers
                (list :anvil
                      (list :command emacs-bin
                            :args (list "--batch"
                                        "-l" "pro-ai-anvil-server-start"
                                        "--eval" "(while (not (input-pending-p)) (sleep-for 1))")
                            :directTools t
                            :lifecycle "keep-alive")))))
    (with-temp-buffer
      (insert (json-encode snippet))
      (kill-new (buffer-string)))
    (with-output-to-temp-buffer "*pro-ai-anvil-setup*"
      (princ "Скопируйте этот фрагмент в local-templates/{pi,opencode}/mcp.json:\n\n")
      (princ (json-encode snippet)))
    (message "[pro-ai-anvil] setup JSON в kill-ring и в *pro-ai-anvil-setup*")))

;; --- Auto-start (если разрешено) ---------------------------------------

(defun pro-ai-anvil--auto-start-fn ()
  "Запустить anvil-server после init, если `pro-ai-anvil-auto-start' = t.
Тихий режим — ошибки только в `*Messages*'."
  (when (and pro-ai-anvil-auto-start
             (not noninteractive)
             (pro-ai-anvil--available-p))
    (condition-case err
        (pro-ai-anvil-server-start)
      (error (message "[pro-ai-anvil] auto-start failed: %S" err)))))

(pro-compat--add-hook-once 'after-init-hook #'pro-ai-anvil--auto-start-fn)

;; --- Клавиши ------------------------------------------------------------

(defun pro-ai-anvil--register-keys ()
  "Зарегистрировать предложения для emacs-keys.org."
  (when (fboundp 'pro/register-module-keys)
    (pro/register-module-keys
     'pro-ai-anvil
     '(("C-c a a" . pro-ai-anvil-server-start)
       ("C-c a s" . pro-ai-anvil-server-stop)
       ("C-c a t" . pro-ai-anvil-server-status)
       ("C-c a l" . pro-ai-anvil-list-tools)
       ("C-c a d" . pro-ai-anvil-describe-setup)))))

(with-eval-after-load 'pro-keys
  (pro-ai-anvil--register-keys))

(provide 'pro-ai-anvil)
;;; pro-ai-anvil.el ends here
