;;; pro-org.el --- орг-работа и таблицы -*- lexical-binding: t; -*-

(require 'pro-compat)

(declare-function org-redisplay-inline-images "org")
(declare-function org-modern-mode "org-modern")

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
        org-table-formula-use-constants nil
        org-src-window-setup 'current-window
        org-confirm-babel-evaluate nil
        org-support-shift-select nil)

  (pro-compat--add-hook-once 'org-babel-after-execute-hook #'org-redisplay-inline-images)

  (setq org-babel-default-header-args '((:results . "value")))

  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (shell . t)
     (dot . t)
     (ditaa . t)
     (plantuml . t)
     (mermaid . t)))

  (when (or (pro--package-provided-p 'org-modern)
            (pro-packages--maybe-install 'org-modern t)
            (require 'org-modern nil t))
    ;; В TTY оставляем простой вид, но в графике включаем более удобную подачу.
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
    (pro-compat--add-to-list-once 'org-src-lang-modes '(plantuml . plantuml))
    (when (boundp 'org-structure-template-alist)
      (pro-compat--add-to-list-once 'org-structure-template-alist '("uml" . "src plantuml :file ./diagram.svg"))))

  ;; Mermaid — обязательное расширение для этого профиля: при отсутствии
  ;; Nix-пакета пробуем автодоставку через package.el.
  (when (or (pro--package-provided-p 'ob-mermaid)
            (pro-packages--maybe-install 'ob-mermaid t)
            (require 'ob-mermaid nil t))
    (pro-compat--add-to-list-once 'org-src-lang-modes '(mermaid . mermaid))))

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

(defun pro-org--bind-keys ()
  "Локальные биндинги для org-буфера. Идемпотентен: local-set-key
перезаписывает, и `pro-compat--add-hook-once' защищает от дублей
при soft reload."
  (local-set-key (kbd "C-c |") #'org-table-create-or-convert-from-region)
  (local-set-key (kbd "C-c t") #'org-table-transpose-table-at-point)
  (local-set-key (kbd "C-c K") #'pro-org-open-keys-file)
  (local-set-key (kbd "C-c M") #'pro-org-open-module-list))

(with-eval-after-load 'org
  ;; Ensure we bind keys after org-mode is loaded. Use `org-mode-hook` to
  ;; avoid assuming `org-mode-map' exists at `with-eval-after-load' time
  ;; which can happen with some load orders. `pro-compat--add-hook-once'
  ;; is what makes soft reload safe: lambda inside `with-eval-after-load'
  ;; is replaced with a named function so idempotency check works.
  (pro-compat--add-hook-once 'org-mode-hook #'pro-org--bind-keys))

(pro-compat--add-hook-once 'org-mode-hook #'pro-org-setup)

;; Provide both pro-prefixed and the traditional `org' feature so external
;; packages (consult/embark etc.) that `require` 'org' still work when the
;; repository's local org module is loaded during tests or containerized runs.
(provide 'pro-org)

;;; pro-org.el ends here
