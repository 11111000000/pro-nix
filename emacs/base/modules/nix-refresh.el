;;; nix-refresh.el --- Refresh load-path from Nix-discovered site-lisp dirs -*- lexical-binding: t; -*-

(defvar pro/nix-site-lisp-paths nil "List of site-lisp paths discovered by Nix generator.")

(defun pro/nix-load-path-refresh (&optional paths)
  "Refresh `load-path' by prepending PATHS (or `pro/nix-site-lisp-paths').
This makes Emacs aware of newly built Nix-provided elisp directories.
Note: native extensions (.so) still require Emacs restart." 
  (interactive)
  (let ((new-paths (or paths pro/nix-site-lisp-paths)))
    (when (and new-paths (listp new-paths))
      (dolist (p (reverse new-paths))
        (when (and p (file-directory-p p) (not (member p load-path)))
          (add-to-list 'load-path p)))
      (message "pro: refreshed load-path with %d nix paths" (length new-paths)))))

(provide 'nix-refresh)
