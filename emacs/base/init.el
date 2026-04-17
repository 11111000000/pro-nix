;;; init.el --- pro Emacs loader -*- lexical-binding: t; -*-

(setq user-emacs-directory (file-name-as-directory (expand-file-name "~/.emacs.d/")))
(load "/etc/pro/emacs/site-init.el" nil t)
(pro-emacs-base-start)

(provide 'pro-init)
