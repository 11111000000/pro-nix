;;; diag-modules.el --- Diagnostics for pro modules -*- lexical-binding: t; -*-
;; Запуск: emacs --batch -l emacs/base/init.el -l emacs/base/tools/diag-modules.el

(message "pro-diag: start")

(let* ((mods-dir (expand-file-name "emacs/base/modules" (file-name-directory (or load-file-name buffer-file-name))))
       (all-files (when (file-directory-p mods-dir) (directory-files mods-dir nil "^pro-.*\\.el$")))
       (all-mods (mapcar (lambda (f) (file-name-sans-extension f)) all-files))
       (default-mods (mapcar (lambda (s) (if (symbolp s) (symbol-name s) (format "%s" s))) pro-emacs-base-default-modules))
       not-provided
       not-resolved)

  (message "pro-diag: default-modules: %S" default-mods)

  ;; Check which default modules are actually provided (featurep) after init
  (dolist (m default-mods)
    (let* ((sym (intern m))
           (provided (featurep sym))
           (resolved (pro-emacs-base--resolve-module m))
           (readable (and resolved (file-readable-p resolved))))
      (unless provided
        (push (list m resolved readable) not-provided))))

  ;; Modules present in repo but not in default manifest
  (let ((extra (cl-set-difference all-mods default-mods :test #'string=)))
    (message "pro-diag: modules present but not in default manifest (%d):" (length extra))
    (dolist (m (sort extra #'string<)) (message "  %s" m)))

  ;; Report default modules not provided
  (if not-provided
      (progn
        (message "pro-diag: default modules NOT provided (%d):" (length not-provided))
        (dolist (e (reverse not-provided))
          (message "  %s -> file=%s readable=%S" (nth 0 e) (or (nth 1 e) "-") (nth 2 e))))
    (message "pro-diag: all default modules provide their features."))

  (message "pro-diag: end"))
