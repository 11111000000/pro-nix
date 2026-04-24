;; Repository fallback for provided packages.
;; This is used when ~/.config/emacs/provided-packages.el is not writable
;; (for example when managed by home-manager). It is generated from
;; nix/provided-packages.nix when preparing the repository for development.

(setq pro-packages-provided-by-nix
      '(magit consult vertico orderless marginalia gptel consult-dash dash-docs consult-eglot consult-yasnippet corfu cape kind-icon avy expand-region yasnippet projectile treemacs vterm ace-window embark
        nerd-icons nerd-icons-completion nerd-icons-ibuffer all-the-icons all-the-icons-completion all-the-icons-dired consult-projectile which-key embark-consult))

(provide 'provided-packages)
