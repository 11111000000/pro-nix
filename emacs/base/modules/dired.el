;;; dired.el --- Dired helpers for pro-nix -*- lexical-binding: t; -*-
;; Minimal, well-tested dired configuration ported from ~/pro with guards

(require 'subr-x)

(defcustom pro-dired-enable t
  "Enable pro dired helpers.
Set to nil to disable."
  :type 'boolean :group 'pro)

(when pro-dired-enable
  (when (require 'dired nil t)
    ;; basic keybindings and hooks
    (with-eval-after-load 'dired
      (let ((map (current-global-map)))
        ;; Do not impose global keys; configure dired-mode-map instead
        (when (boundp 'dired-mode-map)
          (define-key dired-mode-map (kbd "j") #'dired-next-line)
          (define-key dired-mode-map (kbd "k") #'dired-previous-line)
          (define-key dired-mode-map (kbd "l") #'dired-find-file)
          (define-key dired-mode-map (kbd "f") #'dired-find-file)
          (define-key dired-mode-map (kbd "o") #'dired-find-file)
          (define-key dired-mode-map (kbd "RET") #'dired-find-file)
          (define-key dired-mode-map (kbd "h") #'dired-up-directory)
          (define-key dired-mode-map (kbd "^") #'dired-up-directory)
          (define-key dired-mode-map (kbd "C-c r") #'pro/dired-reload-elisp-here))))

    ;; Hooks and settings
    (add-hook 'dired-mode-hook #'dired-hide-details-mode)
    (add-hook 'dired-mode-hook #'hl-line-mode)

    (setq-default dired-listing-switches "-aBhlv --group-directories-first")
    (setq ls-lisp-dirs-first t)
    (setq ls-lisp-use-insert-directory-program nil)
    (setq dired-dwim-target t)
    (setq insert-directory-program "ls")
    (setq dired-use-ls-dired t)
    (setq dired-auto-revert-buffer t)
    (setq global-auto-revert-non-file-buffers t)
    (setq dired-hide-details-hide-symlink-targets nil)

    ;; wdired: enable quick editing
    (when (require 'wdired nil t)
      (with-eval-after-load 'dired
        (define-key dired-mode-map (kbd "C-c C-c") #'wdired-change-to-wdired-mode)
        (with-eval-after-load 'wdired
          (define-key wdired-mode-map (kbd "C-c C-r") #'replace-string)
          (define-key wdired-mode-map (kbd "C-c r") #'replace-regexp)
          (define-key wdired-mode-map (kbd "C-g C-g") #'wdired-exit)
          (define-key wdired-mode-map (kbd "ESC") #'wdired-exit))))

    ;; Optional: treemacs icons in dired when available via ui layer
    (when (and (fboundp 'pro-ui--try-require)
               (pro-ui--try-require 'treemacs-icons-dired))
      (add-hook 'dired-mode-hook #'treemacs-icons-dired-enable-once))

    ;; helper: reload elisp files in marked directory if pro-lisp helper present
    (defun pro/dired-reload-elisp-here ()
      "Reload all .el files in current dired directory if helper present."
      (interactive)
      (when (require 'про-код-на-lisp nil t)
        (when (fboundp 'pro/reload-all-elisp-in-dired-directory)
          (pro/reload-all-elisp-in-dired-directory))))
    )

(provide 'dired-pro)

;;; dired.el ends here
