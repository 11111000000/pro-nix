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
;; Register suggested keys after `keys' is loaded. Use `puthash' directly
;; when the registry is present to avoid surprising evaluation-time issues
;; with reader macros in some environments.
(with-eval-after-load 'pro-keys
  ;; Guard registration so that errors in the registry (for example due to
  ;; evaluation-time ordering bugs or malformed payloads) do not abort
  ;; Emacs startup. Log the error for later inspection.
  (condition-case err
      (cond
       ((and (fboundp 'pro/register-module-keys))
        (pro/register-module-keys 'tabs
                                  '(("C-c t n" . pro-tabs-open-new-tab)
                                    ("C-c t k" . pro-tabs-close-tab-and-buffer)
                                    ("C-c t s" . tab-bar-switch-to-tab))))
       ((and (boundp 'pro/registered-module-keys) (hash-table-p pro/registered-module-keys))
        (puthash 'tabs
                 '(("C-c t n" . pro-tabs-open-new-tab)
                   ("C-c t k" . pro-tabs-close-tab-and-buffer)
                   ("C-c t s" . tab-bar-switch-to-tab))
                 pro/registered-module-keys)))
    ;; Avoid referencing `err` in the message to prevent void-variable
    ;; issues in certain early startup contexts. Detailed diagnostics are
    ;; written to /tmp/pro-register-tabs.log above so operators can inspect
    ;; the raw payload.
    (error
     (ignore-errors
       (with-temp-file "/tmp/pro-register-tabs.log"
         (insert (format "CALL: time=%s module=tabs\n" (current-time-string)))
         (insert "suggested: ((\"C-c t n\" . pro-tabs-open-new-tab) ...)\n"))))
    (message "[pro-tabs] failed to register suggested keys (see /tmp/pro-register-tabs.log)")))

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
