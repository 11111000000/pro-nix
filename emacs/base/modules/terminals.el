;;; terminals.el --- Terminal integration (vterm, eshell helpers) -*- lexical-binding: t; -*-
;; Minimal, opt-in terminal helpers derived from ~/pro. No global keybindings here;
;; suggested keys go to emacs-keys.org.

(require 'subr-x)

(defcustom pro-terminals-enable t
  "Enable pro terminal helpers (vterm/eshell).
Set to nil to disable.
This does not control installation of packages; ensure vterm is available in Nix." 
  :type 'boolean :group 'pro)

(when (and pro-terminals-enable (require 'vterm nil t))
  ;; Example helper: yank into vterm with proper escaping
  (defun pro/vterm-yank ()
    "Yank from kill-ring into vterm with proper handling."
    (interactive)
    (when (derived-mode-p 'vterm-mode)
      (let ((text (current-kill 0)))
        (vterm-send-string text))))

  (defun pro/vterm-interrupt ()
    "Send SIGINT in vterm (C-c C-c equivalent)."
    (interactive)
    (when (derived-mode-p 'vterm-mode)
      (vterm-send-C-c)))

  ;; Setup minor vterm niceties
  (add-hook 'vterm-mode-hook
            (lambda ()
              (setq-local scroll-margin 0)
              ;; enable tab-line in vterm for quick buffer switching
              (when (fboundp 'tab-line-mode) (tab-line-mode 1)))))

(provide 'terminals)
