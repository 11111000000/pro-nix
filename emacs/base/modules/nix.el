;;; nix.el --- Nix editing -*- lexical-binding: t; -*-

(when (require 'nix-mode nil t)
  (add-to-list 'auto-mode-alist '("\\.nix\\'" . nix-mode))
  (add-hook 'nix-mode-hook (lambda ()
                             (setq-local indent-tabs-mode nil)
                             (setq-local tab-width 2))))

(defun pro-nix-rebuild-system ()
  "Собрать систему NixOS из текущего конфига."
  (interactive)
  (compile "sudo nixos-rebuild switch --flake .#pro"))

(defun pro-nix-format-buffer ()
  "Показать явную точку для будущего форматирования Nix-буфера."
  (interactive)
  (message "[pro-nix] formatting hook is intentionally minimal"))

(provide 'nix)
