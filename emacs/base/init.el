;;; init.el --- pro Emacs loader -*- lexical-binding: t; -*-

(let ((base-dir (file-name-directory (or load-file-name buffer-file-name))))
  (setq user-emacs-directory (file-name-as-directory (expand-file-name "~/.config/emacs/")))
  (setq pro-emacs-base-system-modules-dir (expand-file-name "modules" base-dir))
  (load (expand-file-name "site-init.el" base-dir) nil t)
  (pro-emacs-base-start))

(provide 'pro-init)
