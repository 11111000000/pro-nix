;;; init.el --- pro Emacs loader -*- lexical-binding: t; -*-

(let ((base-dir (file-name-directory (or load-file-name buffer-file-name))))
  (setq user-emacs-directory (file-name-as-directory (expand-file-name "~/.config/emacs/")))
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

;; After core init: load optional completion keys and external org key loader
(when (require 'completion-keys nil t)
  ;; completion-keys binds useful C-c o <letter> keys for CAPE and consult-yasnippet
  )

;; Try to load external keybindings loader from ~/pro if present
(let ((keys-loader (expand-file-name "~/pro/организация/про-клавиши-из-org.el")))
  (when (file-exists-p keys-loader)
    (condition-case _err
        (load-file keys-loader)
      (error (message "pro: failed to load keys loader: %s" keys-loader)))
    (when (fboundp 'pro/клавиши-из-org)
      (pro/клавиши-из-org (expand-file-name "~/pro/про-клавиши.org")))))
