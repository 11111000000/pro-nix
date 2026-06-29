;;; pro-dired.el --- Dired helpers for pro-nix -*- lexical-binding: t; -*-
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

    ;; Listing format customization: keep long format as default to preserve tests
    (defcustom pro-dired-prefer-short nil
      "If non-nil, use compact/short `ls' output in dired (one-file-per-line).
Default is nil to preserve test compatibility and familiar long listing."
      :type 'boolean :group 'pro)

    (defcustom pro-dired-long-listing-switches "-aBhlv --group-directories-first"
      "The long-format listing switches used by pro dired (default)."
      :type 'string :group 'pro)

    (defcustom pro-dired-short-listing-switches "-aB1 --group-directories-first"
      "The short/compact listing switches used when `pro-dired-prefer-short' is non-nil.
This produces one file per line with minimal metadata."
      :type 'string :group 'pro)

    (setq-default dired-listing-switches
                  (if pro-dired-prefer-short
                      pro-dired-short-listing-switches
                    pro-dired-long-listing-switches))

    (defun pro/dired-toggle-listing-format ()
      "Toggle between pro dired long and short listing formats.
This flips `pro-dired-prefer-short' and updates `dired-listing-switches' for new buffers."
      (interactive)
      (setq pro-dired-prefer-short (not pro-dired-prefer-short))
      (setq-default dired-listing-switches
                    (if pro-dired-prefer-short
                        pro-dired-short-listing-switches
                      pro-dired-long-listing-switches))
      (message "pro-dired: listing-format => %s"
               (if pro-dired-prefer-short "short" "long")))
    (setq ls-lisp-dirs-first t)
    (setq ls-lisp-use-insert-directory-program nil)
    (setq dired-dwim-target t)
    (setq insert-directory-program "ls")
    (setq dired-use-ls-dired t)
    (setq dired-auto-revert-buffer t)
    ;; Disabled for I/O: pro-dired previously enabled global revert for
    ;; non-file buffers (magit-status, help, *Messages*, *Compile*, ...).
    ;; With eglot + magit + projectile + treemacs running, this made Emacs
    ;; re-read all such buffers periodically and accounted for a large share
    ;; of background disk I/O. File buffers still auto-revert by default;
    ;; only the non-file variant is disabled. Flip back to `t' if you want
    ;; live-updating *Help* / *Messages* / etc.
    (setq global-auto-revert-non-file-buffers nil)
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
    )
  )

(provide 'pro-dired)

;;; pro-dired.el ends here
