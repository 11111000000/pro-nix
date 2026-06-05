;;; pro-windows.el --- Window and buffer management helpers -*- lexical-binding: t; -*-
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
  (when (require 'buffer-move nil t)
    ;; noop - buffer-move provides buffer move functions; keys controlled via emacs-keys.org
    (ignore (fboundp 'buf-move-left)))

  ;; ace-window: optional fast window selection (no keys set here)
  (when (require 'ace-window nil t)
    (setq aw-scope 'global))

  ;; Simple, conservative display-buffer policy for common transient buffers.
  ;; Keep this small and opt-in: users can override in their modules or user config.
  (when (boundp 'display-buffer-alist)
    ;; Plain `vterm' (the buffer named *vterm*) opens in the current window
    ;; without forcing a side window.
    (add-to-list 'display-buffer-alist
                 '("\\*vterm\\*" . ((display-buffer-same-window))))

    ;; multi-vterm buffers are named "*vterminal<N>*" (indexed) or
    ;; "*vterminal - <path>*" (project). Open them in a bottom side window
    ;; taking ~43% of the screen height.
    (add-to-list 'display-buffer-alist
                 '("\\*vterminal[^*]*\\*" . ((display-buffer-in-side-window)
                                              (side . bottom)
                                              (slot . 0)
                                              (window-height . 0.43)
                                              (quit . delete-window))))

    ;; eshell-toggle uses "*et*" buffer names: also a 43% bottom side window.
    (add-to-list 'display-buffer-alist
                 '("\\*et[^*]*\\*" . ((display-buffer-in-side-window)
                                       (side . bottom)
                                       (slot . 0)
                                       (window-height . 0.43)
                                       (quit . delete-window))))

    ;; *Messages*: reuse existing window or show at the bottom with small height
    (add-to-list 'display-buffer-alist
                 '("\\*Messages\*" . ((display-buffer-reuse-window display-buffer-in-side-window)
                                             (side . bottom)
                                             (slot . -1)
                                             (window-height . 0.12))))
    )
  )

;; eshell-toggle splits the current window by `eshell-toggle-size-fraction'.
;; We want the resulting eshell window to occupy ~43% of the screen, so the
;; divisor must be ~1/0.43 ≈ 2.3.  An integer is required, so we use 2
;; (≈ 50%) as a sensible default; users can fine-tune via customise.
(when (boundp 'eshell-toggle-size-fraction)
  (setq eshell-toggle-size-fraction 2))

;; multi-vterm dedicated window height in percent of the frame.
;; Default per the upstream package is a fixed 30 lines; we set it to 43%.
(when (boundp 'multi-vterm-dedicated-window-height-percent)
  (setq multi-vterm-dedicated-window-height-percent 43))

;; --- Window resize (C-x + / C-x -) ---------------------------------------
(defun pro-windows-enlarge ()
  "Увеличить текущее окно на 4 строки (вертикально)."
  (interactive)
  (enlarge-window 4))

(defun pro-windows-shrink ()
  "Уменьшить текущее окно на 4 строки (вертикально)."
  (interactive)
  (shrink-window 4))

(provide 'pro-windows)
