;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; pro-org.el --- орг-работа и таблицы -*- lexical-binding: t; -*-

;; Этот модуль делает Org удобным для заметок, таблиц, задач и ТЗ.

(when (or (pro--package-provided-p 'org) (pro-packages--maybe-install 'org t) (require 'org nil t))
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

(when (or (pro--package-provided-p 'org-tempo) (pro-packages--maybe-install 'org-tempo t) (require 'org-tempo nil t))
  ;; org-tempo registers templates; ensure functions exist before setting the alist.
  (when (boundp 'org-structure-template-alist)
    (setq org-structure-template-alist
          '(("s" . "src")
            ("e" . "example")
            ("q" . "quote")
            ("v" . "verse")
            ("c" . "center")))))

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
  ;; Ensure we bind keys after org-mode is loaded. Use `org-mode-hook` to
  ;; avoid assuming `org-mode-map' exists at `with-eval-after-load' time
  ;; which can happen with some load orders.
  (add-hook 'org-mode-hook
            (lambda ()
              (local-set-key (kbd "C-c |") #'org-table-create-or-convert-from-region)
              (local-set-key (kbd "C-c t") #'org-table-transpose-table-at-point)
              (local-set-key (kbd "C-c K") #'pro-org-open-keys-file)
              (local-set-key (kbd "C-c M") #'pro-org-open-module-list))))

(add-hook 'org-mode-hook #'pro-org-setup)

;; Provide both pro-prefixed and the traditional `org' feature so external
;; packages (consult/embark etc.) that `require` 'org' still work when the
;; repository's local org module is loaded during tests or containerized runs.
(provide 'pro-org)
(provide 'org)

;;; pro-org.el ends here
