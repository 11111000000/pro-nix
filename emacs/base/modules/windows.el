;;; windows.el --- Window and buffer management helpers -*- lexical-binding: t; -*-
;; Lightweight, opt-in configuration for window management: winner-mode, windmove,
;; buf-move, golden-ratio and ace-window integrations. Does NOT set global keybindings;
;; recommended keys go to emacs-keys.org.

(defgroup pro-windows nil
  "Window and buffer management helpers for pro." :group 'pro)

(defcustom pro-windows-enable t
  "Enable pro window management helpers." :type 'boolean :group 'pro-windows)

(when pro-windows-enable
  ;; winner-mode: undo/redo window configurations
  (when (fboundp 'winner-mode)
    (winner-mode 1))

  ;; Windmove: directional movement between windows. We do not bind keys here.
  (when (fboundp 'windmove-default-keybindings)
    ;; do not call windmove-default-keybindings to avoid setting global keys; ensure functions exist
    (ignore (boundp 'windmove-left)))

  ;; Golden ratio: optional cosmetic window sizing
  (when (require 'golden-ratio nil t)
    ;; configure conservative defaults
    (setq golden-ratio-adjust-factor 1.0)
    (setq golden-ratio-wide-adjust-factor 1.0)
    (when (fboundp 'golden-ratio-mode) (golden-ratio-mode 1)))

  ;; buf-move: optional buffer swapping helpers
  (when (require 'buf-move nil t)
    ;; noop - buf-move provides buffer move functions; keys controlled via emacs-keys.org
    (ignore (fboundp 'buf-move-left)))

  ;; ace-window: optional fast window selection (no keys set here)
  (when (require 'ace-window nil t)
    (setq aw-scope 'global))
  )

(provide 'windows)
