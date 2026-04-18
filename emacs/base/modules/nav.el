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

(when (require 'consult nil t)
  (when (require 'consult-xref nil t)
    (setq xref-show-definitions-function #'consult-xref
          xref-show-xrefs-function #'consult-xref)))

(defun pro-nav-open-line ()
  "Открыть строковый поиск."
  (interactive)
  (when (require 'consult nil t)
    (consult-line)))

(provide 'nav)
