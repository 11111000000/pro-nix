;;; pro-nix.el --- Nix editing -*- lexical-binding: t; -*-

(defvar pro-nix-rebuild-target "default"
  "Целевой nixos-конфиг для `nixos-rebuild`.")

(when (or (pro--package-provided-p 'nix-mode) (pro-packages--maybe-install 'nix-mode t) (require 'nix-mode nil t))
  ;; Only register hooks if nix-mode is actually available.
  (when (fboundp 'nix-mode)
    (add-to-list 'auto-mode-alist '("\\.nix\\'" . nix-mode))
    (defun pro-nix--setup-buffer ()
      "Buffer-local settings for nix-mode: tabs off, width 2, comment column 40."
      (setq-local indent-tabs-mode nil)
      (setq-local tab-width 2)
      (setq-local comment-column 40))
    (add-hook 'nix-mode-hook #'pro-nix--setup-buffer)))

(defun pro-nix-rebuild-system ()
  "Собрать систему NixOS из текущего конфига."
  (interactive)
  (compile (format "sudo nixos-rebuild switch --flake .#%s" pro-nix-rebuild-target)))

(defun pro-nix-format-buffer ()
  "Показать явную точку для будущего форматирования Nix-буфера."
  (interactive)
  (message "[pro-nix] formatting hook is intentionally minimal"))

(provide 'pro-nix)
