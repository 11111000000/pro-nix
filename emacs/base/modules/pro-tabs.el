;;; pro-tabs.el --- Minimal pro tabs integration (opt-in) -*- lexical-binding: t; -*-
;; Provides a thin, safe layer over tab-bar/tab-line or an optional pro-tabs
;; package. Does NOT set global keybindings; those live in emacs-keys.org.

(defgroup pro-tabs nil
  "Pro tabs integration (opt-in)."
  :group 'pro)

(defcustom pro-pro-tabs-enable nil
  "Enable pro-tabs integration.
When non-nil, configure tab-bar/tab-line and pro-tabs if available.
This does not install global keybindings; use emacs-keys.org for that." 
  :type 'boolean
  :group 'pro-tabs)

(defun pro-tabs--enable-built-in-tabs ()
  "Enable built-in tab-bar and sensible defaults." 
  (when (fboundp 'tab-bar-mode)
    (tab-bar-mode 1)
    ;; make tab names shorter and useful
    (setq tab-bar-show 1)
    (setq tab-bar-format '(tab-bar-format-tabs tab-bar-separator))
    ;; enable tab-line for per-window buffer tabs if available
    (when (fboundp 'tab-line-mode)
      (tab-line-mode 1))))

(defun pro-tabs-open-new-tab ()
  "Open a new tab (wrapper).
If `pro-tabs' package is present, delegate to it; otherwise use `tab-bar-new-tab'." 
  (interactive)
  (if (fboundp 'pro-tabs-mode)
      (when (fboundp 'pro-tabs-open-new-tab) (pro-tabs-open-new-tab))
    (tab-bar-new-tab)))

;; Register suggested keys only after keys module has loaded to avoid
;; evaluation-time ordering issues when modules are loaded in different contexts.
(with-eval-after-load 'keys
  (when (fboundp 'pro/register-module-keys)
    (pro/register-module-keys 'tabs
                              '( ("C-c t n" . pro-tabs-open-new-tab)
                                 ("C-c t x" . pro-tabs-close-tab-and-buffer)
                                 ("C-c t o" . tab-bar-switch-to-tab)))))

(defun pro-tabs-close-tab-and-buffer ()
  "Close current tab and kill its buffer (wrapper)." 
  (interactive)
  (let ((buf (current-buffer)))
    (when (fboundp 'tab-bar-close-tab)
      (tab-bar-close-tab))
    (when (buffer-live-p buf)
      (kill-buffer buf))))

(when pro-pro-tabs-enable
  ;; attempt to use pro-tabs package if available, otherwise enable built-in
  (if (require 'pro-tabs nil t)
      (when (fboundp 'pro-tabs-mode) (pro-tabs-mode 1))
    (pro-tabs--enable-built-in-tabs)))

(provide 'pro-tabs)
