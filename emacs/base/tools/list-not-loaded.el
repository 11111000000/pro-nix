;; list-not-loaded.el -- list pro-*.el modules that are present but not provided after init
(let* ((mods-dir (expand-file-name "emacs/base/modules" (file-name-directory (or load-file-name buffer-file-name))))
       (files (when (file-directory-p mods-dir) (directory-files mods-dir nil "^pro-.*\\.el$")))
       (not-loaded '()))
  (dolist (f files)
    (let* ((bn (file-name-sans-extension f))
           (feat (intern bn)))
      (unless (featurep feat)
        (push bn not-loaded))))
  (if not-loaded
      (progn
        (princ "Modules present but NOT provided after init:\n")
        (dolist (m (sort not-loaded #'string<)) (princ (format "  %s\n" m))))
    (princ "All pro-*.el modules are provided after init.\n")))
