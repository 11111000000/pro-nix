;;; pro-telega.el --- Дополнительная интеграция с telega (consult + CAPF) -*- lexical-binding: t; -*-
;;
;; Этот модуль надстраивается над `pro-chat', добавляя:
;; - `pro/telega-select-chat-or-contact' — единый consult-выбор чатов
;;   и контактов с narrowing (`c' — только чаты, `u' — только контакты),
;;   аннотациями и настраиваемым предпросмотром.
;; - CAPF автодополнение @упоминаний в telega-chat-mode (по username или имени).
;;
;; Контракт:
;; - Все функции безопасны при отсутствии telega/consult — выводят user-error.
;; - Внутренние хелперы разделены `pro/telega--' префиксом.
;; - Тело модуля ленивое: ничего не вызывается до первого использования
;;   consult/telega пользователем.

(require 'cl-lib)
(require 'subr-x)

(eval-when-compile
  (require 'cl-lib)
  (require 'subr-x))

(defgroup pro/chat-telega nil
  "Дополнительные настройки telega (consult + CAPF)."
  :group 'pro/chat
  :prefix "pro/telega-")

;; -------------------------------------------------------------------
;; CAPF @упоминаний в telega-chat-mode
;; -------------------------------------------------------------------

(defun pro/telega--contacts ()
  "Список контактов пользователя, совместимый с актуальным telega API."
  (cl-remove-if-not
   (lambda (u) (telega-user-match-p u 'contact))
   (ignore-errors (telega-user-list))))

(defun pro/telega--mention-alist ()
  "Alist (username . fullname) для контактов telega.
fullname — склеенные first_name и last_name (может быть пустым).
Если у пользователя несколько активных никнеймов — вернуть все."
  (cl-loop for u in (pro/telega--contacts)
           for fname = (telega--tl-get u :first_name)
           for lname = (telega--tl-get u :last_name)
           for full = (string-trim (mapconcat #'identity
                                              (delq nil (list fname lname))
                                              " "))
           for primary-uname = (telega--tl-get u :username)
           for active = (let ((act (telega--tl-get u :usernames :active_usernames)))
                          (cond
                           ((vectorp act) (append act nil))
                           ((listp act) act)
                           (t nil)))
           for unames = (delete-dups (delq nil (append (list primary-uname) active)))
           append (mapcar (lambda (un) (cons un (unless (string-empty-p full) full)))
                          unames)
           when (not (string-empty-p full))
           collect (cons nil full)))

(defun pro/telega-mention-capf ()
  "CAPF для автодополнения @упоминаний в telega чатах.
Ищет по нику и по имени (включая кириллицу)."
  (when (derived-mode-p 'telega-chat-mode)
    (let* ((pt (point))
           (at-pos (save-excursion
                     (when (search-backward "@" (line-beginning-position) t)
                       (point))))
           (start (and at-pos (1+ at-pos)))
           (valid (and start
                       (<= start pt)
                       (not (string-match-p "\\s-"
                                            (buffer-substring-no-properties start pt))))))
      (when valid
        (let* ((alist (pro/telega--mention-alist))
               (table
                (completion-table-dynamic
                 (lambda (str)
                   (let* ((case-fold-search t)
                          (str-no-at (if (and str (> (length str) 0) (eq (aref str 0) ?@))
                                         (substring str 1)
                                       str)))
                     (cl-loop for (uname . full) in alist
                              for cand = (or uname full)
                              when (and cand
                                        (if uname
                                            (string-match-p (regexp-quote str) uname)
                                          (string-match-p (regexp-quote str-no-at) full)))
                              collect (propertize cand
                                                  'telega-username-p (and uname t)
                                                  'telega-fullname full)))))))
          (list start pt table
                :annotation-function
                (lambda (cand)
                  (let* ((is-user (get-text-property 0 'telega-username-p cand))
                         (full    (get-text-property 0 'telega-fullname cand)))
                    (cond
                     (is-user (concat " @" cand (when full (concat " — " full))))
                     (full    (concat " " full))
                     (t nil))))
                :exclusive 'no))))))

(defun pro/telega-enable-mention-capf ()
  "Включить CAPF @упоминаний в текущем буфере (telega-chat-mode)."
  (add-hook 'completion-at-point-functions #'pro/telega-mention-capf nil t))

(with-eval-after-load 'telega
  (when (boundp 'telega-chat-mode-hook)
    (add-hook 'telega-chat-mode-hook #'pro/telega-enable-mention-capf)))

;; -------------------------------------------------------------------
;; consult-выбор чатов/контактов
;; -------------------------------------------------------------------

(defcustom pro/telega-select-preview 'echo
  "Режим предпросмотра кандидата в `pro/telega-select-chat-or-contact':
- echo: краткая подсказка в echo-area;
- help-window: описание из telega-describe-*;
- nil: без предпросмотра."
  :type '(choice (const :tag "Echo area" echo)
                 (const :tag "Help window" help-window)
                 (const :tag "Disabled" nil))
  :group 'pro/chat-telega)

(defcustom pro/telega-select-include-saved-messages t
  "Включать ли чат «Saved Messages» в начало списка (если он уже существует)."
  :type 'boolean
  :group 'pro/chat-telega)

(defcustom pro/telega-select-show-unread t
  "Показывать ли краткую метку непрочитанного (u, @, rx) в аннотации."
  :type 'boolean
  :group 'pro/chat-telega)

(defvar pro/consult-telega-history nil
  "История ввода для `pro/telega-select-chat-or-contact'.")

(defun pro/telega--ensure-telega ()
  "Проверить, что telega загружена и сервер запущен."
  (unless (require 'telega nil t)
    (user-error "Пакет telega не найден (M-x pro/chat-install)"))
  (when (and (fboundp 'telega-server-live-p)
             (not (telega-server-live-p)))
    (user-error "telega-сервер не запущен (M-x pro/chat-open)")))

(defun pro/telega--ensure-consult ()
  "Проверить, что consult загружен."
  (unless (require 'consult nil t)
    (user-error "Пакет consult не найден")))

(defun pro/telega--chat-choices ()
  "Список чатов для выбора: известные + с открытым chatbuf, отсортированные."
  (let* ((all (ignore-errors
                (telega-filter-chats (telega-chats-list)
                  '(or is-known has-chatbuf)))))
    (telega-sort-chats telega-chat-completing-sort-criteria all)))

(defun pro/telega--user-choices (existing-chats)
  "Список контактов, у которых ещё нет открытого приватного чата."
  (let* ((chats-set (let ((ht (make-hash-table :test 'eq)))
                      (dolist (c existing-chats)
                        (puthash (plist-get c :id) t ht))
                      ht)))
    (cl-remove-if
     (lambda (u)
       (when-let ((chat (telega-user-chat u)))
         (gethash (plist-get chat :id) chats-set)))
     (sort (pro/telega--contacts) #'telega-user>))))

(defun pro/telega--saved-messages-chat ()
  "Чат «Saved Messages», если уже создан."
  (ignore-errors (telega-chat-get telega--me-id 'offline)))

(defun pro/telega--unread-brief (chat)
  "Короткая строка непрочитанного для CHAT: «u:N @:M rx:K»."
  (let ((u (plist-get chat :unread_count))
        (m (plist-get chat :unread_mention_count))
        (r (plist-get chat :unread_reaction_count)))
    (string-join
     (delq nil
           (list (unless (zerop u) (format "u:%d" u))
                 (unless (zerop m) (format "@:%d" m))
                 (unless (zerop r) (format "rx:%d" r))))
     " ")))

(defun pro/telega--display-for-chat (chat)
  "Строка кандидата для CHAT (без аннотации)."
  (concat (telega-msg-sender-title-for-completion chat) "  [chat]"))

(defun pro/telega--display-for-user (user)
  "Строка кандидата для USER (без аннотации)."
  (concat (telega-msg-sender-title-for-completion user) "  [contact]"))

(defun pro/telega--annotator (alist)
  "Функция-аннотация consult для ALIST вида (DISPLAY . (:type :obj))."
  (lambda (cand)
    (when-let* ((entry (assoc cand alist))
                (type (plist-get (cdr entry) :type))
                (obj (plist-get (cdr entry) :obj)))
      (pcase type
        ('chat
         (if (and pro/telega-select-show-unread obj)
             (let ((unread (pro/telega--unread-brief obj)))
               (concat " [chat]" (unless (string-empty-p unread) (concat " " unread))))
           " [chat]"))
        ('user " [contact]")))))

(defun pro/telega--narrow (alist)
  "`:narrow' spec: `c' — только чаты, `u' — только контакты."
  (let ((tbl (make-hash-table :test 'equal)))
    (dolist (e alist)
      (puthash (car e) (plist-get (cdr e) :type) tbl))
    (list
     (cons ?u (lambda (cand) (eq (gethash cand tbl) 'user)))
     (cons ?c (lambda (cand) (eq (gethash cand tbl) 'chat))))))

(defun pro/telega--preview-state (alist)
  "Функция :state для предпросмотра по `pro/telega-select-preview'."
  (let ((last nil))
    (lambda (action cand)
      (pcase action
        ('preview
         (setq last cand)
         (when-let* ((entry (assoc cand alist))
                     (type (plist-get (cdr entry) :type))
                     (obj  (plist-get (cdr entry) :obj)))
           (pcase pro/telega-select-preview
             ('echo
              (pcase type
                ('chat (message "Chat: %s  %s"
                                (telega-chat-title obj 'no-badges)
                                (pro/telega--unread-brief obj)))
                ('user (message "User: %s"
                                (telega-user-title obj 'full-name 'no-badges)))))
             ('help-window
              (pcase type
                ('chat (telega-describe-chat obj))
                ('user (telega-describe-user obj))))
             (_ nil))))
        ((or 'return 'exit)
         (when last (message nil)))))))

(defun pro/telega--build-candidates (mode)
  "Собрать кандидатов. MODE ∈ {both, chat-only, user-only}.
Возвращает (choices-nice . choices-alist)."
  (let* ((chats (pro/telega--chat-choices))
         (users (pro/telega--user-choices chats))
         (acc '()))
    (when (and pro/telega-select-include-saved-messages
               (memq mode '(both chat-only)))
      (when-let ((sm (pro/telega--saved-messages-chat)))
        (push (cons (pro/telega--display-for-chat sm)
                    (list :type 'chat :obj sm))
              acc)))
    (when (memq mode '(both chat-only))
      (dolist (chat chats)
        (push (cons (pro/telega--display-for-chat chat)
                    (list :type 'chat :obj chat))
              acc)))
    (when (memq mode '(both user-only))
      (dolist (user users)
        (push (cons (pro/telega--display-for-user user)
                    (list :type 'user :obj user))
              acc)))
    (setq acc (nreverse acc))
    (cons (mapcar #'car acc) acc)))

;;;###autoload
(defun pro/telega-select-chat-or-contact (&optional arg)
  "Выбрать чат/группу/канал или контакт через consult.
С префиксом ARG:
- C-u     — только чаты;
- C-u C-u — только контакты.
Без префикса — оба вида."
  (interactive "P")
  (pro/telega--ensure-consult)
  (pro/telega--ensure-telega)
  (let* ((mode (cond
                ((equal arg '(4))  'chat-only)
                ((equal arg '(16)) 'user-only)
                (t 'both)))
         (cdata (pro/telega--build-candidates mode))
         (choices (car cdata))
         (alist   (cdr cdata))
         (annot   (pro/telega--annotator alist))
         (narrow  (pro/telega--narrow alist))
         (state   (pro/telega--preview-state alist))
         (prompt  (pcase mode
                    ('chat-only "Telega: чат: ")
                    ('user-only "Telega: контакт: ")
                    (_          "Telega: чат/контакт: ")))
         (selected
          (consult--read choices
                         :prompt prompt
                         :require-match t
                         :history 'pro/consult-telega-history
                         :category 'unicode-name
                         :annotate annot
                         :narrow narrow
                         :sort t
                         :state state))
         (entry (assoc selected alist))
         (type (plist-get (cdr entry) :type))
         (obj  (plist-get (cdr entry) :obj)))
    (pcase type
      ('chat (telega-chat--pop-to-buffer obj))
      ('user (telega-user-chat-with obj)))))

;;;###autoload
(defalias 'pro/telega-select-contact #'pro/telega-select-chat-or-contact)

;; -------------------------------------------------------------------
;; Регистрация предложений клавиш
;; -------------------------------------------------------------------

(with-eval-after-load 'pro-keys
  (when (fboundp 'pro/register-module-keys)
    (pro/register-module-keys
     'telega
     '(("C-c t s" . pro/telega-select-chat-or-contact)
       ("C-c t c" . pro/telega-select-chat-or-contact)
       ("C-c t u" . (lambda () (interactive) (pro/telega-select-chat-or-contact '(16))))))))

(provide 'pro-telega)

;;; pro-telega.el ends here
