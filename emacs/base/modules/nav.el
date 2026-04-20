;;; nav.el --- поиск и навигация -*- lexical-binding: t; -*-

;; Этот модуль задаёт единый путь поиска по файлам, символам и проектам.

(when (require 'vertico nil t)
  (vertico-mode 1)
  (setq vertico-cycle t))

(when (require 'orderless nil t)
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil))

(when (require 'marginalia nil t)
  (marginalia-mode 1))

(when (or (pro--package-provided-p 'consult) (require 'consult nil t))
  (when (require 'consult-xref nil t)
    (setq xref-show-definitions-function #'consult-xref
          xref-show-xrefs-function #'consult-xref)))

(defun pro-nav-search-project ()
  "Искать в текущем проекте, если доступен project root."
  (interactive)
  (if (or (pro--package-provided-p 'consult) (require 'consult nil t))
      (if (fboundp 'pro-project-root)
          (consult-ripgrep (or (pro-project-root) default-directory))
        (consult-ripgrep default-directory))
    (pro-compat--notify-once "consult" "consult missing — pro-nav-search-project fallback to grep")
    (let ((default-directory (or (and (fboundp 'pro-project-root) (pro-project-root)) default-directory)))
      (call-interactively #'grep))))

(defun pro-nav-open-line ()
  "Открыть строковый поиск."
  (interactive)
  (if (or (pro--package-provided-p 'consult) (require 'consult nil t))
      (consult-line)
    (pro-compat--notify-once "consult" "consult missing — pro-nav-open-line fallback to isearch")
    (call-interactively #'isearch-forward)))

(provide 'nav)
