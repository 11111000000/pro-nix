;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; keys.el --- пользовательские клавиши -*- lexical-binding: t; -*-

;; Модуль: keys.el — декларативный интерфейс горячих клавиш.
;;
;; Назначение:
;; Обеспечивает загрузку глобальных и контекстных биндингов из `emacs-keys.org` и
;; `~/.emacs.d/keys.org`. Формат строки — Org-таблица с колонками: SECTION | KEY | COMMAND | ...
;; Модуль сохраняет поведение совместимым с EXWM и org-mode, применяя биндинги
;; с приоритетом: system -> user.

(require 'subr-x)

(defgroup pro nil
  "Базовая группа настроек PRO."
  :group 'applications)

(defconst pro-keys-user-file
  (expand-file-name "keys.org" user-emacs-directory)
  "Путь к пользовательскому файлу клавиш.")

(defconst pro-keys-system-file
  (or (let ((etc-file "/etc/pro/emacs-keys.org"))
        (and (file-readable-p etc-file) etc-file))
      (expand-file-name "../pro/emacs-keys.org" user-emacs-directory))
  "Путь к системному файлу клавиш PRO.")

(defvar pro-keys-exwm-global-keys nil
  "Список глобальных клавиш EXWM, собранный из Org-таблиц.")

(defvar pro-keys-pending-bindings nil
  "Список привязок, которые не удалось применить пока команда не определена.
Каждый элемент — список (SECTION KEY COMMAND). SECTION — :global/:exwm/:org.")

(defun pro-keys--normalize-command-name (text)
  "Нормализовать TEXT как имя команды."
  (replace-regexp-in-string "^#'" "" (pro-keys--trim text)))

(defun pro-keys-apply-binding (key command)
  "Привязать KEY к COMMAND, если KEY не пустой."
  (when (and key command (not (string-empty-p key)))
    (if (and (symbolp command) (fboundp command))
        ;; Apply now when possible
        (global-set-key (kbd key) command)
      ;; Запомним в отложенных привязках — попробуем применить позже.
      (push (list :global key command) pro-keys-pending-bindings))))

(defun pro-keys-apply-exwm-binding (key command)
  "Добавить EXWM-ключ KEY -> COMMAND в отдельный список."
  (when (and key command (not (string-empty-p key)))
    (let ((fn (if (and (symbolp command) (fboundp command)) command nil)))
      (if fn
          (push (cons (kbd key) fn) pro-keys-exwm-global-keys)
        (push (list :exwm key command) pro-keys-pending-bindings)))))

(defun pro-keys--trim (string)
  (string-trim (or string "")))

(defun pro-keys--parse-command (text)
  "Преобразовать TEXT в символ команды."
  (let ((name (pro-keys--normalize-command-name text)))
    ;; Accept a wider set of characters that commonly appear in command
    ;; symbols (slashes for category prefixes like `pro/…', dots, colons, etc).
    ;; Previously the regexp rejected names such as "pro/consult-buffer",
    ;; which left many table rows unparsable and resulted in pending bindings.
    (when (and name
               (not (string-empty-p name))
               (not (string-prefix-p "-" name))
               (string-match-p "^[A-Za-z][A-Za-z0-9_:/.-]*$" name))
      (intern name))))

(defun pro-keys--meaningful-cell-p (text)
  "Проверить, содержит ли TEXT смысловое значение."
  (let ((value (pro-keys--trim text)))
    (and (not (string-empty-p value))
         (string-match-p "[[:alnum:]]" value))))

(defun pro-keys--parse-org-table-line (line)
  "Разобрать строку Org-таблицы с клавишами."
  (let ((parts (split-string line "|" t "[[:space:]]+")))
    (when (>= (length parts) 4)
      (let ((section (upcase (pro-keys--trim (nth 0 parts))))
            (key (pro-keys--trim (nth 1 parts)))
            (command (pro-keys--parse-command (nth 2 parts))))
        (unless (or (not (pro-keys--meaningful-cell-p section))
                    (not (pro-keys--meaningful-cell-p key))
                    (null command))
          (list section key command))))))

(defun pro-keys--table-line-p (line)
  "Проверить, похожа ли строка на строку таблицы клавиш."
  (string-prefix-p "|" (string-trim-left line)))

(defun pro-keys--section-kind (section)
  "Определить тип секции SECTION."
  (pcase section
    ((or "EXWM" "EXWM-S") :exwm)
    ((or "ORG" "ORG-MODE") :org)
    (_ :global)))

(defun pro-keys--apply-row (section key command)
  "Применить строку таблицы SECTION KEY COMMAND."
  (pcase (pro-keys--section-kind section)
    (:exwm (pro-keys-apply-exwm-binding key command))
    (:org
     ;; If the command is already available and org loaded, bind directly to
     ;; the org-mode keymap. Otherwise record pending binding to try later.
     (let ((k key) (cmd command))
        (cond
         ;; If Org is already loaded, bind directly to its keymap. Rely on
         ;; `featurep' instead of `boundp' to avoid referencing the variable
         ;; `org-mode-map' before the Org package is fully initialized which
         ;; can trigger `void-variable' errors during startup.
         ((and (symbolp cmd) (fboundp cmd) (featurep 'org))
          (define-key org-mode-map (kbd k) cmd))
         ((and (symbolp cmd) (fboundp cmd))
          ;; Org not yet loaded — arrange to bind when it is.
          (with-eval-after-load 'org
            (define-key org-mode-map (kbd k) cmd)))
        (t
         (push (list :org k cmd) pro-keys-pending-bindings)))))
    (_ (pro-keys-apply-binding key command))))

(defun pro-keys-load-org-file (file)
  "Загрузить клавиши из Org-файла FILE."
  (when (and file (file-readable-p file))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (not (eobp))
        (let* ((line (buffer-substring-no-properties
                      (line-beginning-position)
                      (line-end-position)))
               (binding (and (pro-keys--table-line-p line)
                             (pro-keys--parse-org-table-line line))))
          (when binding
            (let ((section (nth 0 binding))
                  (key (nth 1 binding))
                  (cmd (nth 2 binding)))
              ;; If the line contains a provenance marker for a module, record it
              ;; for potential rollback. We treat lines preceding the table row
              ;; that match "# PRO-MODULE: <name>" as ownership markers.
              (save-excursion
                (let ((owner nil)
                      (pos (line-beginning-position)))
                  (when (> pos 1)
                    (goto-char (1- pos))
                    (when (re-search-backward "^# PRO-MODULE: \(.*\)$" (point-min) t)
                      (setq owner (match-string 1))))
                  (when owner
                    ;; Record mapping key -> owner in a simple alist
                    (unless (boundp 'pro-keys-provenance)
                      (defvar pro-keys-provenance nil "Alist of (KEY . MODULE) provenance."))
                    (push (cons key owner) pro-keys-provenance))))
            (pro-keys--apply-row (nth 0 binding) (nth 1 binding) (nth 2 binding))))
        (forward-line 1))))))

(defun pro-keys-reload ()
  "Перезагрузить клавиши из системного и пользовательского слоёв."
  (interactive)
  (setq pro-keys-exwm-global-keys nil)
  (pro-keys-load-org-file pro-keys-system-file)
  (pro-keys-load-org-file pro-keys-user-file)
  ;; Попробуем применить отложенные привязки — возможно, нужные функции
  ;; появились к этому моменту.
  (pro-keys-apply-pending)
  (message "[pro-keys] loaded system and user overrides"))

(defun pro-keys-apply-pending ()
  "Попытаться применить ранее отложенные привязки.
Если команда определена — применяем и удаляем запись из списка pending." 
  (interactive)
  (when pro-keys-pending-bindings
    (let ((remaining nil))
      (dolist (entry (nreverse pro-keys-pending-bindings))
        (pcase entry
           (`(:global ,key ,cmd)
            (if (and (symbolp cmd) (fboundp cmd))
                (global-set-key (kbd key) cmd)
              (push entry remaining)))
          (`(:exwm ,key ,cmd)
           (if (and (symbolp cmd) (fboundp cmd))
               (push (cons (kbd key) cmd) pro-keys-exwm-global-keys)
             (push entry remaining)))
          (`(:org ,key ,cmd)
            (if (and (symbolp cmd) (fboundp cmd))
                (if (featurep 'org)
                    (define-key org-mode-map (kbd key) cmd)
                  (with-eval-after-load 'org
                    (define-key org-mode-map (kbd key) cmd)))
             (push entry remaining)))
          (_ (push entry remaining))))
      (setq pro-keys-pending-bindings (nreverse remaining)))
    ;; Если exwm уже загружен, обновим глобальные ключи.
    (when (featurep 'exwm)
      (setq exwm-input-global-keys pro-keys-exwm-global-keys))))

(defun pro-keys-report-pending ()
  "Вывести в журнал список отложенных биндингов (если они есть)."
  (let ((n (length pro-keys-pending-bindings)))
    (if (zerop n)
        (message "[pro-keys] no pending bindings")
      (message "[pro-keys] %d pending bindings remain:" n)
      (dolist (entry pro-keys-pending-bindings)
        (pcase entry
          (`(:global ,key ,cmd)
           (message "  global: %s -> %s" key cmd))
          (`(:exwm ,key ,cmd)
           (message "  exwm: %s -> %s" key cmd))
          (`(:org ,key ,cmd)
           (message "  org: %s -> %s" key cmd))
          (_ (message "  unknown pending entry: %S" entry)))))))

(setq pro-keys-exwm-global-keys nil)
(pro-keys-load-org-file pro-keys-system-file)
(pro-keys-load-org-file pro-keys-user-file)

(with-eval-after-load 'exwm
  (setq exwm-input-global-keys pro-keys-exwm-global-keys))

;; Ensure pending bindings are retried when common lazy packages load.
(dolist (feat '(projectile project consult vertico))
  (with-eval-after-load feat
    (pro-keys-apply-pending)))

;; If which-key is available, ensure it's enabled for discoverability
(when (fboundp 'which-key-mode)
  (with-eval-after-load 'which-key
    (which-key-mode 1)))

;; Provide feature at the end so other modules can `with-eval-after-load` on
;; "keys" and safely call registry functions such as `pro/register-module-keys`.
;; Registry for module-suggested keys (module -> alist of ("KEY" . SYMBOL))
(defvar pro/registered-module-keys (make-hash-table :test 'eq)
  "Hash table mapping module symbol to its suggested keys alist.")

(defun pro/register-module-keys (module keys-alist)
  "Register KEYS-ALIST suggested by MODULE.
KEYS-ALIST is an alist of ("KEY" . command-symbol).
This records suggestions only; it does not apply global bindings.
Use `pro/export-registered-keys-to-org' or `pro/keys-import-suggestions' to
persist or apply suggestions." 
  ;; Be defensive: callers may accidentally pass malformed values which would
  ;; abort Emacs startup. Log a safe representation and tolerate non-list
  ;; inputs.
  (condition-case err
      (when (and module keys-alist)
        (message "pro/register-module-keys: module=%S keys-alist-type=%S" module (type-of keys-alist))
        ;; Normalize to a list if necessary and validate elements.
        (let* ((raw (if (listp keys-alist) keys-alist (list keys-alist)))
               (safe-keys '())
               (preview '()))
          (dolist (e raw)
            (condition-case _
                (when (and (consp e) (stringp (car e)))
                  (push e safe-keys)
                  (push (cons (car e) (if (and (consp e) (symbolp (cdr e))) (cdr e) (format "%S" (cdr e)))) preview))
              (error (push (format "<invalid:%S>" e) preview))))
          (setq safe-keys (nreverse safe-keys))
          (setq preview (nreverse preview))
          (message "pro/register-module-keys: preview=%S" preview)
          (puthash module safe-keys pro/registered-module-keys)
          (let ((n (if (listp safe-keys) (length safe-keys) -1)))
            (message "pro: registered %s suggested keys from %s" (if (>= n 0) (format "%d" n) "(unknown count)") module)))))
    (error
     (message "pro: failed to register module keys for %s: %S" module err))))

(defun pro/unregister-module-keys (module)
  "Unregister keys suggested by MODULE." 
  (remhash module pro/registered-module-keys)
  (message "pro: unregistered keys for %s" module))

(defun pro/list-registered-module-keys ()
  "Return an alist of registered modules and their suggested keys." 
  (let (out)
    (maphash (lambda (k v) (push (cons k v) out)) pro/registered-module-keys)
    out))

(defun pro/export-registered-keys-to-org (&optional out-file)
  "Export registered module key suggestions to OUT-FILE as an Org table.
If OUT-FILE is nil, print the generated content to *Messages* buffer. This
function does not apply the keys; it only writes suggestions for review." 
  (interactive)
  (let ((file (or out-file (expand-file-name "emacs-keys.suggestions.org" temporary-file-directory))))
    (with-temp-file file
      (insert (format "# Generated suggestions at %s\n\n" (current-time-string)))
      (insert "| Section | Key | Command | Note |\n")
      (insert "|--------+-----+---------+------|\n")
      (maphash
       (lambda (mod keys)
         (insert (format "# PRO-MODULE: %s\n" mod))
         (dolist (pair keys)
           (let ((k (car pair)) (cmd (cdr pair)))
             (insert (format "| %s | %s | %s | suggested from %s |\n" "Suggested" k cmd mod)))))
       pro/registered-module-keys))
    (message "pro: exported registered keys to %s" file)
    file))

(defun pro/keys-import-suggestions (&optional out-file)
  "Merge registered module suggestions into the central emacs-keys.org or OUT-FILE.
This writes an Org table fragment annotated with # PRO-MODULE headers for review.
It does not overwrite existing system/user files; it writes to OUT-FILE for manual review.
If OUT-FILE is nil, default to `emacs-keys.suggestions.org` in temp dir.
Return the path of the generated file.
" 
  (interactive)
  (let ((file (or out-file (expand-file-name "emacs-keys.suggestions.org" temporary-file-directory))))
    (with-temp-file file
      (insert (format "# Generated suggestions at %s\n\n" (current-time-string)))
      (insert "| Section | Key | Command | Note |\n")
      (insert "|--------+-----+---------+------|\n")
      (maphash
       (lambda (mod keys)
         (insert (format "# PRO-MODULE: %s\n" mod))
         (dolist (pair keys)
           (let ((k (car pair)) (cmd (cdr pair)))
             (insert (format "| Suggested | %s | %s | suggested from %s |\n" k cmd mod)))))
       pro/registered-module-keys))
    (message "pro: wrote suggestions to %s" file)
    file))

;; Provide this feature after the public API (registry functions) is
;; defined. Placing `provide' earlier could cause `with-eval-after-load'
;; callbacks in other modules to run before the registry functions exist,
;; leading to void-variable / void-function errors during startup.
 (provide 'keys)
