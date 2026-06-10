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
  ;; The package `windmove' ships with Emacs; no external dependency required.
  (when (fboundp 'windmove-default-keybindings)
    ;; do not call windmove-default-keybindings to avoid setting global keys; ensure functions exist
    (ignore (boundp 'windmove-left)))

  ;; buf-move: built-in buffer-swap helpers on top of `windmove'.
  ;; No external package: the four interactive commands are defined below.
  ;; Key bindings (s-H/J/K/L in the EXWM input map) live in emacs-keys.org.
  (defun pro-windows--buf-snapshot (window)
    "Capture WINDOW's buffer-related state for later restoration."
    (list (window-buffer window)
          (window-start window)
          (window-hscroll window)
          (window-point window)))
  (defun pro-windows--buf-restore (window snapshot)
    "Restore WINDOW from a SNAPSHOT produced by `pro-windows--buf-snapshot'."
    (set-window-buffer window (nth 0 snapshot))
    (set-window-start   window (nth 1 snapshot))
    (set-window-hscroll window (nth 2 snapshot))
    (set-window-point   window (nth 3 snapshot)))
  (defun pro-windows--buf-move-to (direction)
    "Swap the current window's buffer with the neighbour window in DIRECTION.
DIRECTION is one of `up', `down', `left', `right' (a `windmove' direction).
Signal an error if no neighbour exists, or the target window is
dedicated or is the minibuffer."
    (let* ((this-window (selected-window))
           (other-window (windmove-find-other-window direction))
           (this-snapshot (pro-windows--buf-snapshot this-window)))
      (cond
       ((null other-window)                (user-error "No window %s of the current one" direction))
       ((window-dedicated-p other-window) (user-error "Window %s of the current one is dedicated" direction))
       ((window-minibuffer-p other-window)(user-error "Window %s of the current one is the minibuffer" direction)))
      (pro-windows--buf-restore this-window  (pro-windows--buf-snapshot other-window))
      (pro-windows--buf-restore other-window this-snapshot)
      (select-window other-window)))
  (defun pro-windows-buf-move-up    () (interactive) (pro-windows--buf-move-to 'up))
  (defun pro-windows-buf-move-down  () (interactive) (pro-windows--buf-move-to 'down))
  (defun pro-windows-buf-move-left  () (interactive) (pro-windows--buf-move-to 'left))
  (defun pro-windows-buf-move-right () (interactive) (pro-windows--buf-move-to 'right))

  ;; Golden ratio: optional cosmetic window sizing
  (when (require 'golden-ratio nil t)
    ;; configure conservative defaults
    (setq golden-ratio-adjust-factor 1.0)
    (setq golden-ratio-wide-adjust-factor 1.0)
    (when (fboundp 'golden-ratio-mode) (golden-ratio-mode 1)))

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
