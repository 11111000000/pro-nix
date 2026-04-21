;;; nav.el --- поиск и навигация -*- lexical-binding: t; -*-

;; Этот модуль задаёт единый путь поиска по файлам, символам и проектам.

(when (or (pro--package-provided-p 'vertico) (pro-packages--maybe-install 'vertico t) (require 'vertico nil t))
  ;; vertico-mode might not be defined (package not fully loaded or autoloads missing).
  ;; Guard the call to avoid "Symbol's function definition is void: vertico-mode" during init.
  (when (fboundp 'vertico-mode)
    (vertico-mode 1)
    (setq vertico-cycle t)))

(when (or (pro--package-provided-p 'orderless) (pro-packages--maybe-install 'orderless t) (require 'orderless nil t))
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil))

(when (or (pro--package-provided-p 'marginalia) (pro-packages--maybe-install 'marginalia t) (require 'marginalia nil t))
  ;; marginalia-mode might not be autoloaded even if the package is present.
  (when (fboundp 'marginalia-mode)
    (marginalia-mode 1)))

  (when (or (pro--package-provided-p 'consult) (pro-packages--maybe-install 'consult t) (require 'consult nil t))
    (when (or (pro--package-provided-p 'consult-xref) (pro-packages--maybe-install 'consult-xref t) (require 'consult-xref nil t))
      ;; consult-xref might not be loaded yet; only assign functions if available.
      (when (fboundp 'consult-xref)
        (setq xref-show-definitions-function #'consult-xref
              xref-show-xrefs-function #'consult-xref)))))

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
