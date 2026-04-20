;;; keys.el --- пользовательские клавиши -*- lexical-binding: t; -*-

;; Этот модуль задаёт дефолты клавиш и позволяет пользователю переопределять их через Org-таблицу.

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

(defun pro-keys--normalize-command-name (text)
  "Нормализовать TEXT как имя команды."
  (replace-regexp-in-string "^#'" "" (pro-keys--trim text)))

(defun pro-keys-apply-binding (key command)
  "Привязать KEY к COMMAND, если KEY не пустой."
  (when (and key command (not (string-empty-p key)))
    (if (and (symbolp command) (fboundp command))
        (global-set-key (kbd key) command)
      (message "[pro-keys] command %s not found for key %s" command key))))

(defun pro-keys-apply-exwm-binding (key command)
  "Добавить EXWM-ключ KEY -> COMMAND в отдельный список."
  (when (and key command (not (string-empty-p key)))
    (let ((fn (if (and (symbolp command) (fboundp command)) command nil)))
      (when fn
        (push (cons (kbd key) fn) pro-keys-exwm-global-keys)))))

(defun pro-keys--trim (string)
  (string-trim (or string "")))

(defun pro-keys--parse-command (text)
  "Преобразовать TEXT в символ команды."
  (let ((name (pro-keys--normalize-command-name text)))
    (when (and name
               (not (string-empty-p name))
               (not (string-prefix-p "-" name))
               (string-match-p "^[A-Za-z][A-Za-z0-9_-]*$" name))
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
    (:org (with-eval-after-load 'org
            (when (boundp 'org-mode-map)
              (define-key org-mode-map (kbd key) command))))
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
            (pro-keys--apply-row (nth 0 binding) (nth 1 binding) (nth 2 binding))))
        (forward-line 1)))))

(defun pro-keys-reload ()
  "Перезагрузить клавиши из системного и пользовательского слоёв."
  (interactive)
  (setq pro-keys-exwm-global-keys nil)
  (pro-keys-load-org-file pro-keys-system-file)
  (pro-keys-load-org-file pro-keys-user-file)
  (message "[pro-keys] loaded system and user overrides"))

(setq pro-keys-exwm-global-keys nil)
(pro-keys-load-org-file pro-keys-system-file)
(pro-keys-load-org-file pro-keys-user-file)

(with-eval-after-load 'exwm
  (setq exwm-input-global-keys pro-keys-exwm-global-keys))

(provide 'keys)
