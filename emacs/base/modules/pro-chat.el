;;; pro-chat.el --- Telegram (telega.el) — установка, настройка, команды -*- lexical-binding: t; -*-
;;
;; Модуль предоставляет полную интеграцию с Telegram через telega.el:
;; - Включение telega c настройками (docker-сервер, фильтр Unread, etc.).
;; - Команды: `pro/chat-open', `pro/chat-close-idle', `pro/chat-reload-emojis'.
;; - Локальные биндинги в telega-chat-mode (отправка по C-RET, цитирование reply и т.п.).
;; - Хуки: telega-notifications-mode, отключение auto-fill, hl-line в списке чатов.
;; - Регистрация предложений для глобального keys-слоя (pro/register-module-keys).
;;
;; Контракт:
;; - Если пакет `telega' недоступен в runtime — модуль остаётся «молчаливым»:
;;   публичные функции выводят информативное сообщение и не падают.
;; - Все правки тел — idемпотентны, можно вызывать `pro/reload-config' повторно.
;; - telega объявлен в `pro.emacs.providedPackages' (Nix → /share/emacs/site-lisp).

(require 'cl-lib)
(require 'subr-x)
(require 'pro-compat)

(defgroup pro/chat nil
  "Настройки telega/Telegram для pro-конфигурации."
  :group 'applications
  :prefix "pro/chat-")

(defcustom pro/chat-use-docker t
  "Запускать telega-server через Docker вместо локального tdlib.
Требует установленный Docker (см. virtualisation.docker в NixOS).
Если `telega-server' уже доступен в PATH — можно поставить nil."
  :type 'boolean
  :group 'pro/chat)

(defcustom pro/chat-emoji-font-family "Noto Color Emoji"
  "Шрифт для отображения эмодзи в telega."
  :type 'string
  :group 'pro/chat)

(defcustom pro/chat-fill-column 80
  "Ширина telega-chat-fill-column (nil — отключить)."
  :type '(choice integer (const :tag "Disabled" nil))
  :group 'pro/chat)

(defcustom pro/chat-history-limit 100
  "Сколько последних сообщений подгружать в чат-буфер."
  :type 'integer
  :group 'pro/chat)

;; -------------------------------------------------------------------
;; Загрузка и базовая настройка telega
;; -------------------------------------------------------------------

(defun pro/chat--available-p ()
  "Не-p если пакет telega доступен в runtime."
  (or (featurep 'telega) (require 'telega nil t)))

(defun pro/chat--server-live-p ()
  "Не-p если telega-сервер запущен и соединение с tdlib активно."
  (and (fboundp 'telega-server-live-p) (telega-server-live-p)))

(defun pro/chat--declared-p ()
  "Не-p если telega заявлен в Nix (см. `pro-packages-provided-by-nix')."
  (and (boundp 'pro-packages-provided-by-nix)
       (memq 'telega pro-packages-provided-by-nix)))

(defun pro/chat--apply-base-config ()
  "Применить базовые кастомайз-переменные telega. Идемпотентно.

Используем `customize-set-variable' вместо `setq' потому что
`telega-use-docker' и другие — это defcustom-переменные telega.el.
При повторном `require' telega фреймворк customize восстанавливает
дефолт (`nil' для use-docker), затирая обычный setq. customize-set
записывает значение как user-saved, и оно переживает reload.
"
  (when (fboundp 'customize-set-variable)
    (customize-set-variable 'telega-use-docker pro/chat-use-docker)
    (customize-set-variable 'telega-chat-list-default-filter "Unread")
    (customize-set-variable 'telega-use-images t)
    (customize-set-variable 'telega-emoji-use-images nil)
    (customize-set-variable 'telega-chat-show-avatars nil)
    (customize-set-variable 'telega-chat-show-photos nil)
    (customize-set-variable 'telega-root-auto-fill-mode nil)
    (customize-set-variable 'telega-chat-auto-fill-mode nil)
    (customize-set-variable 'telega-webpage-preview-mode nil)
    (customize-set-variable 'telega-chat-fill-column pro/chat-fill-column)
    (customize-set-variable 'telega-chat-history-limit pro/chat-history-limit)
    (customize-set-variable 'telega-emoji-font-family pro/chat-emoji-font-family)))

(defun pro/chat--install-hooks ()
  "Подключить локальные хуки telega. Вызывать после (require 'telega).
Идемпотентен: каждый хук добавляется через `pro-compat--add-hook-once',
поэтому повторные вызовы (например, после soft reload) не дублируют."
  (condition-case err
      (progn
        (when (boundp 'telega-load-hook)
          (pro-compat--add-hook-once 'telega-load-hook #'global-telega-url-shorten-mode))
        (when (boundp 'telega-root-mode-hook)
          (pro-compat--add-hook-once 'telega-root-mode-hook #'telega-notifications-mode)
          (pro-compat--add-hook-once 'telega-root-mode-hook #'hl-line-mode)
          (pro-compat--add-hook-once 'telega-root-mode-hook
                                     (lambda () (when (fboundp 'telega-root-auto-fill-mode)
                                                  (telega-root-auto-fill-mode -1)))))
        (when (boundp 'telega-chat-mode-hook)
          (pro-compat--add-hook-once 'telega-chat-mode-hook
                                     (lambda () (when (fboundp 'telega-chat-auto-fill-mode)
                                                  (telega-chat-auto-fill-mode -1))))
          ;; TAB в чатах → completion-at-point (для CAPF-упоминаний).
          (pro-compat--add-hook-once 'telega-chat-mode-hook
                                     (lambda ()
                                       (when (derived-mode-p 'telega-chat-mode)
                                         (local-set-key (kbd "TAB") #'completion-at-point)
                                         (local-set-key [tab] #'completion-at-point))))))
    (error (message "[pro-chat] install hooks failed: %S" err))))

(defun pro/chat--bootstrap ()
  "Точка входа: обеспечить telega, применить конфиг и хуки."
  (condition-case err
      (cond
       ((pro/chat--available-p)
        (pro/chat--apply-base-config)
        (pro/chat--install-hooks)
        (message "[pro-chat] telega готов (use-docker=%s)" pro/chat-use-docker))
       ((pro/chat--declared-p)
        (message "[pro-chat] telega заявлен в Nix, но не найден в runtime; M-x pro/chat-install"))
       (t
        (message "[pro-chat] telega недоступен; пропускаю инициализацию")))
    (error (message "[pro-chat] bootstrap error: %S" err))))

;; Запускаем сразу при загрузке модуля.
(pro/chat--bootstrap)

;; -------------------------------------------------------------------
;; Публичные команды
;; -------------------------------------------------------------------

(defun pro/chat-open ()
  "Открыть Telegram. Запускает telega-сервер при первом вызове."
  (interactive)
  (cond
   ((pro/chat--available-p)
    (if (pro/chat--server-live-p)
        (call-interactively #'telega)
      (message "[pro-chat] запуск telega-сервера, подождите...")
      (call-interactively #'telega)))
   ((pro/chat--declared-p)
    (message "[pro-chat] telega заявлен в Nix, но отсутствует в load-path. Перезапустите Emacs."))
   (t
    (message "[pro-chat] пакет telega не найден. M-x pro/chat-install для установки."))))

(defun pro/chat-close-idle-chats ()
  "Закрыть все *Telega Chat* буферы, кроме текущего.
Полезно после долгой сессии, чтобы убрать неиспользуемые окна."
  (interactive)
  (unless (pro/chat--available-p)
    (user-error "telega не загружен"))
  (let* ((current (current-buffer))
         (killed 0))
    (dolist (buf (buffer-list))
      (when (and (not (eq buf current))
                 (string-match-p "^\\*Telega Chat" (buffer-name buf)))
        (kill-buffer buf)
        (setq killed (1+ killed))))
    (message "[pro-chat] закрыто idle-чатов: %d" killed)))

(defun pro/chat-reload-emojis ()
  "Перезагрузить alist эмодзи telega (после смены шрифта)."
  (interactive)
  (unless (pro/chat--available-p)
    (user-error "telega не загружен"))
  (when (fboundp 'telega-emoji--load)
    (telega-emoji--load)
    (message "[pro-chat] эмодзи перезагружены")))

(defun pro/chat-install ()
  "Попытаться установить telega из MELPA через `pro-packages-ensure'.
Идемпотентно — если telega уже есть, ничего не делает."
  (interactive)
  (condition-case err
      (let ((ok (pro/packages-ensure 'telega t)))
        (cond
         (ok
          (if (require 'telega nil t)
              (progn (pro/chat--apply-base-config)
                     (pro/chat--install-hooks)
                     (message "[pro-chat] telega установлен и настроен"))
            (message "[pro-chat] telega установлен, но не загружен — перезапустите Emacs")))
         (t
          (message "[pro-chat] не удалось установить telega (проверьте сеть/архивы MELPA)"))))
    (error (message "[pro-chat] ошибка установки: %S" err))))

;; -------------------------------------------------------------------
;; Регистрация предложений клавиш (pro-keys слой)
;; -------------------------------------------------------------------

(with-eval-after-load 'pro-keys
  (when (fboundp 'pro/register-module-keys)
    (pro/register-module-keys
     'chat
     '(("C-c t o" . pro/chat-open)
       ("C-c t k" . pro/chat-close-idle-chats)
       ("C-c t e" . pro/chat-reload-emojis)
       ("C-c t i" . pro/chat-install)))))

(provide 'pro-chat)

;;; pro-chat.el ends here
