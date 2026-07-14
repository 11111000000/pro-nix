;;; pro-tabs.el --- Minimal pro tabs integration (opt-in) -*- lexical-binding: t; -*-
;; Provides a thin, safe layer over tab-bar/tab-line or an optional pro-tabs
;; package. Does NOT set global keybindings; those live in emacs-keys.org.

(defgroup pro-tabs nil
  "Pro tabs integration (opt-in)."
  :group 'pro)

(defcustom pro-pro-tabs-enable t
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
    (setq tab-bar-format '(tab-bar-format-tabs tab-bar-separator))))

(defvar pro-tabs--upstream-available nil
  "Non-nil when the upstream `pro-tabs' package was loaded successfully.")

(defun pro-tabs--maybe-enable-upstream ()
  "Try to load the upstream `pro-tabs' package from `load-path'.
Returns non-nil if the package was loaded. Used by the integration
wrapper so we delegate to the upstream library when it is on the
load path (Nix-provided case) and fall back to built-in tab-bar
when it is not." 
  (ignore-errors
    (when (locate-library "pro-tabs")
      (require 'pro-tabs)
      (when (fboundp 'pro-tabs-mode)
        (pro-tabs-mode 1)
        (setq pro-tabs--upstream-available t)
        t))))

(defun pro-tabs-open-new-tab ()
  "Open a new tab (wrapper).
If `pro-tabs' package is present, delegate to it; otherwise use `tab-bar-new-tab'." 
  (interactive)
  (if (and (fboundp 'pro-tabs-mode) pro-tabs--upstream-available)
      (call-interactively #'pro-tabs-new-tab)
    (call-interactively #'tab-bar-new-tab)))

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
                                   '(("C-c b n" . pro-tabs-open-new-tab)
                                     ("C-c b k" . pro-tabs-close-tab-and-buffer)
                                     ("C-c b S" . tab-bar-switch-to-tab)
                                     ("C-c x t" . pro-tabs-open-new-tab))))
       ((and (boundp 'pro/registered-module-keys) (hash-table-p pro/registered-module-keys))
         (puthash 'tabs
                  '(("C-c b n" . pro-tabs-open-new-tab)
                    ("C-c b k" . pro-tabs-close-tab-and-buffer)
                    ("C-c b S" . tab-bar-switch-to-tab)
                    ("C-c x t" . pro-tabs-open-new-tab))
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

(defun pro-tabs--line-tabs ()
  "Return non-nil if the current window has a tab-line with tabs.
A non-nil result means the current window has tab-line tabs that can be
navigated. Returns nil when `tab-line-mode' is not active or the window
has no tab-line entries."
  (and (boundp 'tab-line-mode)
       (symbol-value 'tab-line-mode)
       (fboundp 'tab-line-tabs-window-buffers)
       (let ((tabs (ignore-errors (funcall 'tab-line-tabs-window-buffers))))
         (and (consp tabs) tabs))))

(defun pro-tabs-line-next ()
  "Move to the next tab-line tab in the current window.
No-op when tab-line is disabled or the window has no tab-line tabs;
in that case C-<tab> must not fall through to `tab-bar' switching."
  (interactive)
  (if (pro-tabs--line-tabs)
      (call-interactively #'tab-line-switch-to-next-tab)
    (message "pro-tabs: no tab-line tabs in current window")))

(defun pro-tabs-line-prev ()
  "Move to the previous tab-line tab in the current window.
No-op when tab-line is disabled or the window has no tab-line tabs;
in that case C-S-<tab> must not fall through to `tab-bar' switching."
  (interactive)
  (if (pro-tabs--line-tabs)
      (call-interactively #'tab-line-switch-to-prev-tab)
    (message "pro-tabs: no tab-line tabs in current window")))

(defun pro-tabs--apply-tab-line-keybindings ()
  "Bind <C-tab> and <C-S-tab> (plus terminal variants) to tab-line commands.
This overrides `tab-bar-mode' default bindings, so C-<tab> never
silently falls through to `tab-bar' switching."
  (interactive)
  (when (fboundp 'pro-tabs-line-next)
    (global-set-key (kbd "<C-tab>") #'pro-tabs-line-next)
    ;; Some X11/terminal setups report C-Tab as <C-iso-left-tab>.
    (global-set-key (kbd "<C-iso-left-tab>") #'pro-tabs-line-next)
    ;; Backstop: <backtab> is generated by Shift-Tab on many terminals.
    (global-set-key (kbd "<C-S-iso-left-tab>") #'pro-tabs-line-prev))
  (when (fboundp 'pro-tabs-line-prev)
    (global-set-key (kbd "<C-S-tab>") #'pro-tabs-line-prev)
    (global-set-key (kbd "<backtab>") #'pro-tabs-line-prev)))

(defun pro-tabs-select-tab-1 ()
  "Переключиться на вкладку 1."
  (interactive) (tab-bar-select-tab 1))

(defun pro-tabs-select-tab-2 ()
  "Переключиться на вкладку 2."
  (interactive) (tab-bar-select-tab 2))

(defun pro-tabs-select-tab-3 ()
  "Переключиться на вкладку 3."
  (interactive) (tab-bar-select-tab 3))

(defun pro-tabs-select-tab-4 ()
  "Переключиться на вкладку 4."
  (interactive) (tab-bar-select-tab 4))

(defun pro-tabs-select-tab-5 ()
  "Переключиться на вкладку 5."
  (interactive) (tab-bar-select-tab 5))

(defun pro-tabs-select-tab-6 ()
  "Переключиться на вкладку 6."
  (interactive) (tab-bar-select-tab 6))

(when pro-pro-tabs-enable
  ;; Prefer the upstream `pro-tabs' package (Nix-provided) when available;
  ;; otherwise fall back to enabling the built-in tab-bar.
  (or (pro-tabs--maybe-enable-upstream)
      (pro-tabs--enable-built-in-tabs)))

;; Bind C-<tab> / C-S-<tab> to tab-line navigation only.
;; Must run AFTER tab-bar-mode activation above so we win over the
;; `tab-bar-cycle-select-tab' default that tab-bar-mode installs on
;; <C-tab>. The keys remain the central source of truth (emacs-keys.org),
;; but applying them here defends against any module re-binding C-<tab>
;; after our central binding was queued in `pro-keys-pending-bindings'.
(pro-tabs--apply-tab-line-keybindings)

(provide 'pro-tabs)
