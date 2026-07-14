;;; pro-windows.el --- Window and buffer management helpers -*- lexical-binding: t; -*-
;; Lightweight, opt-in configuration for window management: winner-mode, windmove,
;; buffer-move, golden-ratio and ace-window integrations.
;;
;; Public commands:
;; - pro-windows-enlarge / pro-windows-shrink / pro-windows-balance  — global on C-x +/-/=
;; - pro/split-window-sensibly  — balanced split (C-c w s)
;;
;; Bиндинги C-c w * регистрируются через pro/register-module-keys и попадают
;; в emacs-keys.org как глобальные.

(defgroup pro-windows nil
  "Window and buffer management helpers for pro." :group 'pro)

(defcustom pro-windows-enable t
  "Enable pro window management helpers." :type 'boolean :group 'pro-windows)

(when pro-windows-enable
  ;; winner-mode: undo/redo window configurations
  (when (fboundp 'winner-mode)
    (winner-mode 1))

  ;; Windmove: directional movement between windows.
  ;; The package `windmove' ships with Emacs; no external dependency required.
  ;; We do not call windmove-default-keybindings to avoid setting global keys;
  ;; emacs-keys.org handles those via C-c w hjkl.
  (when (fboundp 'windmove-default-keybindings)
    (ignore (boundp 'windmove-left)))

  ;; buffer-move: external package providing `buf-move-up/down/left/right'.
  ;; Swap (or move, when no neighbour) the current window's buffer with the
  ;; neighbour in the given direction. Key bindings (C-c w HJKL) live in
  ;; emacs-keys.org.
  (when (require 'buffer-move nil t)
    (setq buffer-move-stay-after-swap t))

  ;; Golden ratio: loaded as a library, NOT enabled globally.
  (when (require 'golden-ratio nil t)
    (setq golden-ratio-adjust-factor 1.0)
    (setq golden-ratio-wide-adjust-factor 1.0)
    (setq golden-ratio-auto-scale 0)
    (setq golden-ratio-exclude-modes '(dired-mode magit-mode vterm-mode)))

  ;; ace-window: optional fast window selection (no keys set here)
  (when (require 'ace-window nil t)
    (setq aw-scope 'global))

  ;; Display-buffer policy for common transient buffers.
  (when (boundp 'display-buffer-alist)
    (add-to-list 'display-buffer-alist
                 '("\\*vterm\\*" . ((display-buffer-same-window))))
    (add-to-list 'display-buffer-alist
                 '("\\*vterminal[^*]*\\*" . ((display-buffer-in-side-window)
                                               (side . bottom)
                                               (slot . 0)
                                               (window-height . 0.43)
                                               (quit . delete-window))))
    (add-to-list 'display-buffer-alist
                 '("\\*et[^*]*\\*" . ((display-buffer-in-side-window)
                                       (side . bottom)
                                       (slot . 0)
                                       (window-height . 0.43)
                                       (quit . delete-window))))
    (add-to-list 'display-buffer-alist
                 '("\\*Messages\\*" . ((display-buffer-reuse-window display-buffer-in-side-window)
                                       (side . bottom)
                                       (slot . -1)
                                       (window-height . 0.12))))))

;; ── Window resize (C-x + / C-x - / C-x =) ────────────────────────────────

(defun pro-windows-enlarge ()
  "Enlarge the current window. C-u N controls step size."
  (interactive)
  (enlarge-window (prefix-numeric-value current-prefix-arg) 1))

(defun pro-windows-shrink ()
  "Shrink the current window. C-u N controls step size."
  (interactive)
  (shrink-window (prefix-numeric-value current-prefix-arg) 1))

(defun pro-windows-balance ()
  "Balance all windows, then one-shot golden-ratio if available."
  (interactive)
  (balance-windows)
  (when (fboundp 'golden-ratio)
    (golden-ratio)))

;; ── Split helpers (C-c w 1/2/3/s) ───────────────────────────────────────

(defun pro/split-window-sensibly (&optional arg)
  "Разделить окно sensibly: вертикально если широкое, иначе горизонтально.
С префиксом C-u — force vertical. С C-u C-u — force horizontal."
  (interactive "P")
  (let ((vertical (cond
                   ((equal arg '(4)) t)   ; C-u
                   ((equal arg '(16)) nil); C-u C-u
                   (t (> (window-width) (* 2 (window-height)))))))
    (if vertical
        (split-window-right)
      (split-window-below))))

;; ── Register module suggestions for keys layer ──────────────────────────

(with-eval-after-load 'pro-keys
  (when (fboundp 'pro/register-module-keys)
    (pro/register-module-keys
     'windows
     '(("C-c w h" . windmove-left)
       ("C-c w j" . windmove-down)
       ("C-c w k" . windmove-up)
       ("C-c w l" . windmove-right)
       ("C-c w H" . buf-move-left)
       ("C-c w J" . buf-move-down)
       ("C-c w K" . buf-move-up)
       ("C-c w L" . buf-move-right)
       ("C-c w u" . winner-undo)
       ("C-c w r" . winner-redo)
       ("C-c w =" . pro-windows-balance)
       ("C-c w d" . delete-window)
       ("C-c w a" . ace-window)
       ("C-c w 1" . delete-other-windows)
       ("C-c w 2" . split-window-below)
       ("C-c w 3" . split-window-right)
       ("C-c w s" . pro/split-window-sensibly)
       ("C-c w ?" . pro/windows-transient)))))

(provide 'pro-windows)
;;; pro-windows.el ends here
