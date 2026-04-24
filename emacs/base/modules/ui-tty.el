;;; ui-tty.el --- Terminal / TTY UI adaptations -*- lexical-binding: t; -*-

(defgroup pro-ui-tty nil
  "TTY-specific UI adjustments for pro UI"
  :group 'pro-ui)

(defun pro-ui--tty-p ()
  "Return non-nil when running in a text terminal." (not (display-graphic-p)))

(defvar pro-ui--tty-hook-installed nil "Whether TTY hooks installed.")

(defun pro-ui-tty-cleanup-buffer ()
  "Disable symbol prettification and heavy visual modes in current buffer." 
  (when (bound-and-true-p prettify-symbols-mode)
    (prettify-symbols-mode -1))
  (when (fboundp 'display-line-numbers-mode)
    (display-line-numbers-mode -1)))

(defun pro-ui-tty-setup ()
  "Apply TTY specific optimizations. Safe to call multiple times." 
  (when (pro-ui--tty-p)
    (setq-default org-ellipsis "..." org-pretty-entities nil)
    (unless pro-ui--tty-hook-installed
      (setq pro-ui--tty-hook-installed t)
      (add-hook 'after-change-major-mode-hook #'pro-ui-tty-cleanup-buffer))
    (dolist (b (buffer-list)) (with-current-buffer b (pro-ui-tty-cleanup-buffer)))
    ;; Basic terminal-friendly defaults
    (setq fast-but-imprecise-scrolling t
          redisplay-skip-fontification-on-input t
          jit-lock-defer-time 0.05)
    (setq gc-cons-threshold (* 20 1024 1024)) ; TTY-friendly GC
    (when (fboundp 'show-paren-mode) (show-paren-mode -1))
    (when (fboundp 'global-display-line-numbers-mode) (global-display-line-numbers-mode -1))
    (column-number-mode -1)))

(add-hook 'after-init-hook #'pro-ui-tty-setup)

(provide 'ui-tty)
