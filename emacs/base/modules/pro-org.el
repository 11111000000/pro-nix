;;; pro-org.el --- org integration -*- lexical-binding: t; -*-

(require 'pro-compat)

(declare-function org-redisplay-inline-images "org")
(declare-function org-modern-mode "org-modern")

(when (or (pro--package-provided-p 'org)
          (pro-packages--maybe-install 'org t)
          (require 'org nil t))
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
        org-table-formula-use-constants nil
        org-src-window-setup 'current-window
        org-confirm-babel-evaluate nil
        org-support-shift-select nil)
  (pro-compat--add-hook-once 'org-babel-after-execute-hook #'org-redisplay-inline-images)
  (setq org-babel-default-header-args '((:results . "value")))
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t) (shell . t) (dot . t) (ditaa . t) (plantuml . t)))
  (when (or (pro--package-provided-p 'ob-mermaid)
            (pro-packages--maybe-install 'ob-mermaid t)
            (require 'ob-mermaid nil t))
    (org-babel-do-load-languages 'org-babel-load-languages '((mermaid . t)))
    (pro-compat--add-to-list-once 'org-src-lang-modes '(mermaid . mermaid)))
  (when (or (pro--package-provided-p 'org-modern)
            (pro-packages--maybe-install 'org-modern t)
            (require 'org-modern nil t))
    (setq org-hide-emphasis-markers nil
          org-modern-tag t
          org-modern-block-fringe t
          org-modern-table t
          org-modern-priority nil
          org-modern-todo-faces nil
          org-modern-statistics nil
          org-modern-progress nil
          org-modern-invisible-editing 'show-and-error)
    (pro-compat--add-hook-once 'org-mode-hook #'org-modern-mode))
  (when (or (pro--package-provided-p 'plantuml-mode)
            (pro-packages--maybe-install 'plantuml-mode t)
            (require 'plantuml-mode nil t))
    (setq plantuml-default-exec-mode 'jar
          org-plantuml-jar-path "/usr/share/plantuml/plantuml.jar"
          plantuml-jar-path "/usr/share/plantuml/plantuml.jar")
         (pro-compat--add-to-list-once 'org-src-lang-modes '(plantuml . plantuml))))

(when (or (pro--package-provided-p 'org-tempo)
          (pro-packages--maybe-install 'org-tempo t)
          (require 'org-tempo nil t))
  (when (boundp 'org-structure-template-alist)
    (setq org-structure-template-alist
          '(("s" . "src") ("e" . "example") ("q" . "quote")
            ("v" . "verse") ("c" . "center")))))

(defun pro-org-open-keys-file ()
  (interactive)
  (find-file (expand-file-name "keys.org" user-emacs-directory)))

(defun pro-org-open-module-list ()
  (interactive)
  (find-file (expand-file-name "modules.el" user-emacs-directory)))

(defun pro-org-setup ()
  (setq-local truncate-lines nil)
  (setq-local word-wrap t))

(defun pro-org--bind-keys ()
  (local-set-key (kbd "C-c |") #'org-table-create-or-convert-from-region)
  (local-set-key (kbd "C-c t") #'org-table-transpose-table-at-point)
  (local-set-key (kbd "C-c K") #'pro-org-open-keys-file)
  (local-set-key (kbd "C-c M") #'pro-org-open-module-list))

(with-eval-after-load 'org
  (pro-compat--add-hook-once 'org-mode-hook #'pro-org--bind-keys))
(pro-compat--add-hook-once 'org-mode-hook #'pro-org-setup)

(provide 'pro-org)
;;; pro-org.el ends here
