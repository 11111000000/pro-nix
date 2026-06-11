;;; pro-windows.el --- Window and buffer management helpers -*- lexical-binding: t; -*-
;; Lightweight, opt-in configuration for window management: winner-mode, windmove,
;; buffer-move, golden-ratio and ace-window integrations. Does NOT set global
;; keybindings; recommended keys go to emacs-keys.org.

(defgroup pro-windows nil
  "Window and buffer management helpers for pro." :group 'pro)

(defcustom pro-windows-enable t
  "Enable pro window management helpers." :type 'boolean :group 'pro-windows)

(when pro-windows-enable
  ;; winner-mode: undo/redo window configurations
  (when (fboundp 'winner-mode)
    (winner-mode 1))

  ;; Windmove: directional movement between windows. We do not bind keys here.
  ;; The package `windmove' ships with Emacs; no external dependency required.
  (when (fboundp 'windmove-default-keybindings)
    ;; do not call windmove-default-keybindings to avoid setting global keys; ensure functions exist
    (ignore (boundp 'windmove-left)))

  ;; buffer-move: external package providing `buf-move-up/down/left/right' —
  ;; swap (or move, when no neighbour) the current window's buffer with the
  ;; neighbour in the given direction. Key bindings (s-h/j/k/l for focus,
  ;; s-H/J/K/L for buffer-swap) live in emacs-keys.org.
  (when (require 'buffer-move nil t)
    ;; Stay in the original window after a swap so the next `buf-move-*'
    ;; operates on the buffer we just moved, not the one we received.
    (setq buffer-move-stay-after-swap t))

  ;; Golden ratio: optional smart window sizing.
  ;;
  ;; `golden-ratio-mode' watches window/buffer changes and resizes the focused
  ;; window toward φ ≈ 0.618 of the frame.  It composes naturally with
  ;; manual `balance-windows' / per-window `golden-ratio' calls (those are
  ;; idempotent — the next focus change re-applies the ratio).
  (when (require 'golden-ratio nil t)
    ;; Conservative defaults: only resize on user actions, never pop up.
    (setq golden-ratio-adjust-factor 1.0)
    (setq golden-ratio-wide-adjust-factor 1.0)
    (setq golden-ratio-auto-scale 0)
    (setq golden-ratio-exclude-modes '(dired-mode magit-mode vterm-mode))
    (when (fboundp 'golden-ratio-mode)
      (golden-ratio-mode 1)))

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
;;
;; Three levels, with golden-ratio as the smart top tier:
;;
;;   C-x + (pro-windows-enlarge)   — подогнать текущее окно по золотому сечению
;;                                  (если пакет `golden-ratio' доступен; иначе
;;                                   fallback к `enlarge-window 4').
;;   C-x - (pro-windows-shrink)    — выровнять все окна поровну
;;                                  (`balance-windows'; иначе `shrink-window 4').
;;   C-x = (pro-windows-balance)   — выровнять + применить golden-ratio.
;;
;; Bиндинги — в emacs-keys.org.

(defun pro-windows-enlarge ()
  "Подогнать текущее окно по золотому сечению (golden-ratio).
Fallback: enlarge-window 4, если пакет `golden-ratio' не загружен.
Биндинг: C-x + (см. emacs-keys.org)."
  (interactive)
  (if (fboundp 'golden-ratio)
      (golden-ratio)
    (enlarge-window 4)))

(defun pro-windows-shrink ()
  "Выровнять все окна поровну (`balance-windows').
Fallback: shrink-window 4, если golden-ratio-mode не активен.
Биндинг: C-x - (см. emacs-keys.org)."
  (interactive)
  (if (and (boundp 'golden-ratio-mode) golden-ratio-mode)
      (balance-windows)
    (shrink-window 4)))

;; --- Window balance (C-x =) ----------------------------------------------
;; Поведение в духе golden-ratio:
;;   1) выровнять все окна одинаково (`balance-windows');
;;   2) подогнать текущее окно под золотое сечение (`golden-ratio'),
;;      если пакет `golden-ratio' загружен (см. `pro-windows-enable' выше).
;; Fallback: если `golden-ratio' не загружен — только `balance-windows'.
(defun pro-windows-balance ()
  "Выровнять все окна, затем (если доступен) применить golden-ratio.
Биндинг: C-x = (см. emacs-keys.org)."
  (interactive)
  (balance-windows)
  (when (fboundp 'golden-ratio)
    (golden-ratio)))

(provide 'pro-windows)
