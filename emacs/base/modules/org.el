;;; org.el --- орг-работа и таблицы -*- lexical-binding: t; -*-

;; Этот модуль делает Org удобным для заметок, таблиц, задач и ТЗ.

(when (require 'org nil t)
  (setq org-startup-indented t
        org-hide-emphasis-markers t
        org-src-fontify-natively t
        org-pretty-entities t
        org-use-sub-superscripts nil
        org-src-preserve-indentation t
        org-edit-src-content-indentation 0
        org-M-RET-may-split-line nil
        org-table-auto-blank-field t
        org-return-follows-link t
        org-image-actual-width nil
        org-table-formula-use-constants nil))

(when (require 'org-tempo nil t)
  (setq org-structure-template-alist
        '(("s" . "src")
          ("e" . "example")
          ("q" . "quote")
          ("v" . "verse")
          ("c" . "center"))))

(defun pro-org-open-keys-file ()
  "Открыть пользовательский файл клавиш."
  (interactive)
  (find-file (expand-file-name "keys.org" user-emacs-directory)))

(defun pro-org-open-module-list ()
  "Открыть пользовательский список модулей."
  (interactive)
  (find-file (expand-file-name "modules.el" user-emacs-directory)))

(defun pro-org-setup ()
  "Собрать полезные локальные привычки для Org-блоков и таблиц."
  (setq-local truncate-lines nil)
  (setq-local word-wrap t))

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c |") #'org-table-create-or-convert-from-region)
  (define-key org-mode-map (kbd "C-c t") #'org-table-transpose-table-at-point)
  (define-key org-mode-map (kbd "C-c K") #'pro-org-open-keys-file)
  (define-key org-mode-map (kbd "C-c M") #'pro-org-open-module-list))

(add-hook 'org-mode-hook #'pro-org-setup)

(provide 'org)
