;;; pro-keys.el --- Пользовательские клавиши и система предложений -*- lexical-binding: t; -*-
;;
;; Модуль: keys.el — декларативный интерфейс горячих клавиш.
;;
;; Назначение:
;; Обеспечивает загрузку глобальных и контекстных биндингов из `emacs-keys.org` и
;; `~/.emacs.d/keys.org`. Формат строки — Org-таблица с колонками: SECTION | KEY | COMMAND | ...
;; Модуль сохраняет поведение совместимым с EXWM и org-mode, применяя биндинги
;; с приоритетом: system -> user.

(require 'subr-x)

(defgroup pro nil
  "Базовая группа настроек PRO.

Эта группа используется для общих `defcustom' переменных, которые не
попадают в узкоспециализированные подгруппы. При проектировании
интерфейса модуля мы предпочитаем явное именование групп, однако для
совместимости оставляем простой корневой `pro'."
  :group 'applications)

(defconst pro-keys-user-file
  (expand-file-name "keys.org" user-emacs-directory)
  "Путь к пользовательскому файлу клавиш.")

(defconst pro-keys-system-file
  (or (let ((etc-file "/etc/pro/emacs-keys.org"))
        (and (file-readable-p etc-file) etc-file))
      ;; В режиме разработки мы ожидаем, что системный файл может
      ;; располагаться в репозитории рядом с инициализатором.
      (expand-file-name "pro/emacs-keys.org" (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name)))))
  "Путь к системному файлу клавиш PRO. По умолчанию ищем /etc/..., затем
файл в репозитории. Пользовательский файл по-прежнему в ~/.config/emacs/keys.org.")

(defvar pro-keys-exwm-global-keys nil
  "Список глобальных клавиш EXWM, собранный из Org-таблиц.")

(defvar pro-keys-pending-bindings nil
  "Список привязок, которые не удалось применить пока команда не определена.
Каждый элемент — список (SECTION KEY COMMAND). SECTION — :global/:exwm/:org.")

(defun pro-keys--normalize-command-name (text)
  "Нормализовать TEXT как имя команды. Удаляет префикс #', если есть." 
  (replace-regexp-in-string "^#'" "" (pro-keys--trim text)))

(defun pro-keys-apply-binding (key command)
  "Привязать KEY к COMMAND, если KEY не пустой. COMMAND — символ или строка.
Если команда ещё не определена — сохраняем в отложенные привязки." 
  (when (and key command (not (string-empty-p key)))
    (if (and (symbolp command) (fboundp command))
        (global-set-key (kbd key) command)
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
     (let ((k key) (cmd command))
       (cond
        ((and (symbolp cmd) (fboundp cmd) (featurep 'org))
         (define-key org-mode-map (kbd k) cmd))
        ((and (symbolp cmd) (fboundp cmd))
         (with-eval-after-load 'org
           (define-key org-mode-map (kbd k) cmd)))
        (t (push (list :org k cmd) pro-keys-pending-bindings)))))
    (_ (pro-keys-apply-binding key command))))

(defun pro-keys-load-org-file (file)
  "Загрузить клавиши из Org-файла FILE." 
  (when (and file (file-readable-p file))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (not (eobp))
        (let* ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
               (binding (and (pro-keys--table-line-p line) (pro-keys--parse-org-table-line line))))
          (when binding
            (let ((section (nth 0 binding)) (key (nth 1 binding)) (cmd (nth 2 binding)))
              (save-excursion
                (let ((owner nil) (pos (line-beginning-position)))
                  (when (> pos 1)
                    (goto-char (1- pos))
                    (when (re-search-backward "^# PRO-MODULE: \(.*\)$" (point-min) t)
                      (setq owner (match-string 1))))
                  (when owner
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
  (pro-keys-apply-pending)
  (message "[pro-keys] loaded system and user overrides"))

(defun pro-keys-apply-pending ()
  "Попытаться применить ранее отложенные привязки." 
  (interactive)
  (when pro-keys-pending-bindings
    (let ((remaining nil))
      (dolist (entry (nreverse pro-keys-pending-bindings))
        (pcase entry
          (`(:global ,key ,cmd)
           (let ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd)))))
             ;; If the command is not defined but there is a package that
             ;; typically provides it, try to require that package now.
             (unless (fboundp sym)
               (cond
                ((memq sym '(pro-packages pro-packages-install pro-packages-menu pro-packages-refresh pro-packages-upgrade-all pro-packages-upgrade-built-ins)) (ignore-errors (require 'pro-packages nil t)))
                ((memq sym '(cape-keyword cape-symbol cape-file cape-dabbrev cape-history)) (ignore-errors (require 'cape nil t) (ignore-errors (require 'cape-keyword nil t))))
                ((memq sym '(projectile-find-file projectile-switch-project)) (ignore-errors (require 'projectile nil t)))
                ((memq sym '(treemacs)) (ignore-errors (require 'treemacs nil t)))
                ((memq sym '(consult-imenu consult-ripgrep consult-goto-line consult-yasnippet consult-eglot-symbols)) (ignore-errors (require 'consult nil t)))
                ((memq sym '(eldoc-box-help-at-point)) (ignore-errors (require 'eldoc-box nil t)))
                ((memq sym '(exwm-reset exwm-workspace-switch)) (when (display-graphic-p) (ignore-errors (require 'exwm nil t)))))
             ;; If symbol contains a slash (eg. er/expand-region), try requiring
             ;; both parts as packages: before and after the slash.
             (unless (or (fboundp sym) (not (string-match-p "/" (symbol-name sym))))
               (let* ((parts (split-string (symbol-name sym) "/"))
                      (first (intern (car parts)))
                      (second (intern (cadr parts))))
                 (ignore-errors (require second nil t))
                 (ignore-errors (require first nil t))))
             (if (and (symbolp sym) (fboundp sym))
                 (global-set-key (kbd key) sym)
               (push entry remaining)))))
          (`(:exwm ,key ,cmd)
           (let ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd)))))
             (when (display-graphic-p)
               (unless (fboundp sym)
                 (ignore-errors (require 'exwm nil t)))
               (if (and (symbolp sym) (fboundp sym))
                   (push (cons (kbd key) sym) pro-keys-exwm-global-keys)
                 (push entry remaining)))) )
          (`(:org ,key ,cmd)
           (let ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd)))))
             (unless (fboundp sym)
               (ignore-errors (require 'org nil t))
               (ignore-errors (require sym nil t)))
             (if (and (symbolp sym) (fboundp sym))
                 (if (featurep 'org)
                     (define-key org-mode-map (kbd key) sym)
                   (with-eval-after-load 'org
                     (define-key org-mode-map (kbd key) sym)))
               (push entry remaining))))
          (_ (push entry remaining))))
      (setq pro-keys-pending-bindings (nreverse remaining)))
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
          (`(:global ,key ,cmd) (message "  global: %s -> %s" key cmd))
          (`(:exwm ,key ,cmd) (message "  exwm: %s -> %s" key cmd))
          (`(:org ,key ,cmd) (message "  org: %s -> %s" key cmd))
          (_ (message "  unknown pending entry: %S" entry)))))))

(setq pro-keys-exwm-global-keys nil)
(pro-keys-load-org-file pro-keys-system-file)
(pro-keys-load-org-file pro-keys-user-file)

(with-eval-after-load 'exwm
  (setq exwm-input-global-keys pro-keys-exwm-global-keys))

(dolist (feat '(projectile project consult vertico))
  (with-eval-after-load feat
    (pro-keys-apply-pending)))

(when (fboundp 'which-key-mode)
  (with-eval-after-load 'which-key
    (which-key-mode 1)))

;; Registry for module-suggested keys
(defvar pro/registered-module-keys (make-hash-table :test 'eq)
  "Hash table mapping module symbol to its suggested keys alist.")

(defun pro/register-module-keys (module keys-alist)
  "Register KEYS-ALIST suggested by MODULE.
KEYS-ALIST is an alist of ("KEY" . command-symbol)."
  (condition-case err
      (when (and module keys-alist)
        (let ((module-id (if (symbolp module) (symbol-name module) (format "%S" module))))
          (ignore-errors
            (let ((file (format "/tmp/pro-register-%s.log" module-id)))
              (with-temp-file file
                (insert (format "CALL: time=%s module=%s type=%S\n" (current-time-string) module-id (type-of keys-alist)))
                (prin1 keys-alist (current-buffer))))))
        (message "pro/register-module-keys: module=%s" module-id)
        (let* ((raw (if (listp keys-alist) keys-alist (list keys-alist))) (safe-keys '()) (preview '()))
          (dolist (e raw)
            (condition-case _ (when (and (consp e) (stringp (car e))) (push e safe-keys) (push (cons (car e) (if (and (consp e) (symbolp (cdr e))) (cdr e) (format "%S" (cdr e)))) preview)) (error (push (format "<invalid:%S>" e) preview))))
          (setq safe-keys (nreverse safe-keys) preview (nreverse preview))
          (puthash module safe-keys pro/registered-module-keys)
          (message "pro: registered %s suggested keys from %s" (if (listp safe-keys) (format "%d" (length safe-keys)) "(unknown)") module-id))))
    (error (message "pro: failed to register module keys for %s" (or (and (boundp 'module-id) module-id) "<module?>"))))

(defun pro/export-registered-keys-to-org (&optional out-file)
  "Export registered module key suggestions to OUT-FILE as an Org table." 
  (interactive)
  (let ((file (or out-file (expand-file-name "emacs-keys.suggestions.org" temporary-file-directory))))
    (with-temp-file file
      (insert (format "# Generated suggestions at %s\n\n" (current-time-string)))
      (insert "| Section | Key | Command | Note |\n")
      (insert "|--------+-----+---------+------|\n")
      (maphash (lambda (mod keys) (insert (format "# PRO-MODULE: %s\n" mod)) (dolist (pair keys) (let ((k (car pair)) (cmd (cdr pair))) (insert (format "| %s | %s | %s | suggested from %s |\n" "Suggested" k cmd mod))))) pro/registered-module-keys))
    (message "pro: exported registered keys to %s" file)
    file))

(defun pro/keys-import-suggestions (&optional out-file)
  "Merge registered module suggestions into the central emacs-keys.org or OUT-FILE." 
  (interactive)
  (let ((file (or out-file (expand-file-name "emacs-keys.suggestions.org" temporary-file-directory))))
    (with-temp-file file
      (insert (format "# Generated suggestions at %s\n\n" (current-time-string)))
      (insert "| Section | Key | Command | Note |\n")
      (insert "|--------+-----+---------+------|\n")
      (maphash (lambda (mod keys) (insert (format "# PRO-MODULE: %s\n" mod)) (dolist (pair keys) (let ((k (car pair)) (cmd (cdr pair))) (insert (format "| Suggested | %s | %s | suggested from %s |\n" k cmd mod))))) pro/registered-module-keys))
    (message "pro: wrote suggestions to %s" file)
    file))

;; Provide the feature
(provide 'pro-keys)

;;; pro-keys.el ends here
