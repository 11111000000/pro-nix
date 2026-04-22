;;; init.el --- pro Emacs loader -*- lexical-binding: t; -*-

(let ((base-dir (file-name-directory (or load-file-name buffer-file-name))))
  (setq user-emacs-directory (file-name-as-directory (expand-file-name "~/.config/emacs/")))
  ;; Ensure Emacs customizations are written to a user-writable file under
  ;; user-emacs-directory rather than (by default) into the main init file
  ;; which in Nix/Home‑Manager setups may live in a read-only /nix/store.
  (setq custom-file (expand-file-name "custom.el" user-emacs-directory))
  (when (file-exists-p custom-file)
    (load custom-file nil t))
  (setq pro-emacs-base-system-modules-dir (expand-file-name "modules" base-dir))
  ;; Load pro-compat and pro-packages early so modules can consult them
  (when (file-readable-p (expand-file-name "pro-compat.el" pro-emacs-base-system-modules-dir))
    (load (expand-file-name "pro-compat.el" pro-emacs-base-system-modules-dir) nil t))
  (when (file-readable-p (expand-file-name "pro-packages.el" pro-emacs-base-system-modules-dir))
    (load (expand-file-name "pro-packages.el" pro-emacs-base-system-modules-dir) nil t))
  ;; Now load site-init which will load configured modules
  (load (expand-file-name "site-init.el" base-dir) nil t)
  (pro-emacs-base-start))

(provide 'pro-init)
