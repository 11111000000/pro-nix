;;; nix.el --- Nix editing -*- lexical-binding: t; -*-

(when (require 'nix-mode nil t)
  (add-to-list 'auto-mode-alist '("\\.nix\\'" . nix-mode)))

(provide 'nix)
