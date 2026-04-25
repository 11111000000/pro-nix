;;; collect-nix-vs-references.el --- Compare referenced packages vs Nix-provided list
;; Usage: emacs --batch -Q -l emacs/base/tools/collect-nix-vs-references.el

(defun cnvr--scan-modules-for-packages (dir)
  "Return a list of package symbols referenced in DIR modules.
Searches for patterns: pro-packages--maybe-install 'pkg, pro--package-provided-p 'pkg
and (require 'pkg)." 
  (let ((files (when (file-directory-p dir) (directory-files dir t "\\.el$")))
        (out '()))
    (dolist (f files)
      (with-temp-buffer
        (insert-file-contents f)
        (goto-char (point-min))
        (while (re-search-forward "pro-packages--maybe-install\s-+'\([A-Za-z0-9_-]+\)" nil t)
          (push (intern (match-string 1)) out))
        (goto-char (point-min))
        (while (re-search-forward "pro--package-provided-p\s-+'\([A-Za-z0-9_-]+\)" nil t)
          (push (intern (match-string 1)) out))
        (goto-char (point-min))
        (while (re-search-forward "(require\s-+'\([A-Za-z0-9_-]+\)" nil t)
          (let ((sym (intern (match-string 1))))
            (unless (string-prefix-p "pro-" (symbol-name sym)) (push sym out))))))
    (delete-dups out)))

(defun cnvr--read-provided-packages (file)
  "Read pro-packages-provided-by-nix list from FILE and return list of symbols.
If FILE missing, return nil." 
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (when (re-search-forward "(setq\s-+pro-packages-provided-by-nix\s-+'(\([^)]+\))" nil t)
        (let ((body (match-string 1)))
          (mapcar #'intern (split-string (replace-regexp-in-string "[[:space:],]+" " " body) " ")))))))

(require 'cl-lib)
(let* ((repo (file-name-directory (or load-file-name buffer-file-name)))
       (mods (expand-file-name "emacs/base/modules" repo))
       (provided-file (expand-file-name "emacs/base/provided-packages.el" repo))
       (refs (sort (mapcar #'symbol-name (cnvr--scan-modules-for-packages mods)) #'string<))
       (provided (sort (mapcar #'symbol-name (or (cnvr--read-provided-packages provided-file) '() )) #'string<))
       (refs-only (cl-set-difference refs provided :test #'string=))
       (provided-only (cl-set-difference provided refs :test #'string=)))

  (princ "Referenced packages found in modules (unique):\n")
  (dolist (r refs) (princ (format "  %s\n" r)))
  (princ "\nNix-provided packages (from emacs/base/provided-packages.el):\n")
  (dolist (p provided) (princ (format "  %s\n" p)))
  (princ "\nReferenced but NOT provided by Nix:\n")
  (dolist (r refs-only) (princ (format "  %s\n" r)))
  (princ "\nProvided by Nix but NOT referenced in modules:\n")
  (dolist (p provided-only) (princ (format "  %s\n" p)))
  )
