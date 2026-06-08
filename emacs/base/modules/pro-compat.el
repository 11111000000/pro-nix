;;; pro-compat.el --- small compatibility shims -*- lexical-binding: t; -*-

(require 'subr-x)

(defvar pro-compat--notified (make-hash-table :test 'equal)
  "Hash for features we've notified about this session.")

(defun pro-compat--notify-once (key fmt &rest args)
  "Notify once per session for KEY with FMT and ARGS." 
  (unless (gethash key pro-compat--notified)
    (puthash key t pro-compat--notified)
    (apply #'message (concat "[pro-compat] " fmt) args)))

;; UI zoom functions
(unless (fboundp 'pro-ui-zoom-in)
  ;; Use a buffer-local text scaling approach rather than changing the global
  ;; `pro-ui-font-height'. The latter adjusts the default face globally which
  ;; affects all buffers/frames. Using `text-scale-*' functions keeps the
  ;; zoom local to the current buffer and matches expected behaviour for
  ;; C-+ / C-- / C-0 keybindings.
  (defvar pro-ui-zoom-step 1 "Zoom step in text-scale steps (each step ~10%).")
  (defun pro-ui--current-text-scale ()
    "Return current buffer-local text scale amount (may be nil)."
    (if (boundp 'text-scale-mode-amount)
        text-scale-mode-amount
      0))
  (defun pro-ui-zoom-in (&optional steps)
    "Increase buffer-local text scale by STEPS (default 1)."
    (interactive "p")
    (let ((s (or steps 1)))
      (if (fboundp 'text-scale-increase)
          (progn
            (text-scale-increase s)
            (message "Buffer text-scale: %s" (pro-ui--current-text-scale)))
        (pro-compat--notify-once "text-scale" "text-scale functions not available — cannot zoom"))))
  (defun pro-ui-zoom-out (&optional steps)
    "Decrease buffer-local text scale by STEPS (default 1)."
    (interactive "p")
    (let ((s (or steps 1)))
      (if (fboundp 'text-scale-increase)
          (progn
            (text-scale-increase (- s))
            (message "Buffer text-scale: %s" (pro-ui--current-text-scale)))
        (pro-compat--notify-once "text-scale" "text-scale functions not available — cannot zoom"))))
  (defun pro-ui-zoom-reset ()
    "Reset buffer-local text scale to default (0)."
    (interactive)
    (if (fboundp 'text-scale-set)
        (progn
          (text-scale-set 0)
          (message "Buffer text-scale reset to 0"))
      (pro-compat--notify-once "text-scale" "text-scale-set not available — cannot reset zoom"))))

;; Minimal consult fallbacks
(unless (fboundp 'consult-line)
  (defun consult-line (&rest _)
    (interactive)
    (if (and (require 'consult nil t) (fboundp 'consult-line))
        (call-interactively #'consult-line)
      (pro-compat--notify-once "consult" "'consult' missing — falling back to isearch")
      (call-interactively #'isearch-forward))))

(unless (fboundp 'consult-buffer)
  (defun consult-buffer (&rest _)
    (interactive)
    (if (and (require 'consult nil t) (fboundp 'consult-buffer))
        (call-interactively #'consult-buffer)
      (pro-compat--notify-once "consult-buffer" "'consult-buffer' missing — falling back to ibuffer")
      (call-interactively #'ibuffer))))

;; Minimal magit fallbacks
(unless (fboundp 'magit-status)
  (defun magit-status (&rest args)
    (interactive)
    (if (and (require 'magit nil t) (fboundp 'magit-status))
        (apply #'magit-status args)
      (pro-compat--notify-once "magit" "'magit' missing — falling back to vc-dir")
      (call-interactively #'vc-dir))))

;; Idempotency helpers for soft reload
;; pro/reload-config (pro-reload.el) re-runs top-level code of every module
;; via `load-file'. Without guards, every reload would add-hook the same
;; callback again, advice-add the same advice again, add-to-list the same
;; item again. Use these helpers in module top-level code.
(defun pro-compat--add-hook-once (hook function &optional depth local)
  "Add FUNCTION to HOOK only if not already there. Like `add-hook',
but idempotent across `load-file'. LOCAL/DEPTH forwarded.
`symbol-value' returns the local binding when LOCAL is t and the
default value otherwise — correct for both cases.
No-op if HOOK is not bound (e.g. mode-specific hook whose mode is
not loaded yet); the next module reload, or the mode's own init,
will pick it up."
  (when (boundp hook)
    (unless (memq function (symbol-value hook))
      (add-hook hook function depth local))))

(defun pro-compat--add-to-list-once (symbol element &optional append compare-fn)
  "Add ELEMENT to SYMBOL's list only if not present. Idempotent.
APPEND/COMPARE-FN forwarded to `add-to-list'."
  (unless (member element (symbol-value symbol))
    (add-to-list symbol element append compare-fn)))

(defun pro-compat--advice-add-once (function where advice &optional props)
  "Add ADVICE to FUNCTION/WHERE only if not already there. Idempotent.
PROPS forwarded to `advice-add'. Uses `advice-member-p' for the check."
  (unless (advice-member-p advice function)
    (apply #'advice-add function where advice (and props (list props)))))

;; Compatibility: org-plist-delete was removed from org-macs in newer
;; org versions, but svg-lib (svg-lib-button-mode) still calls it.
(unless (fboundp 'org-plist-delete)
  (defun org-plist-delete (plist property)
    "Delete PROPERTY from PLIST.
This is in contrast to merely setting it to 0."
    (let (p)
      (while plist
        (if (not (eq property (car plist)))
            (setq p (plist-put p (car plist) (nth 1 plist))))
        (setq plist (cddr plist)))
      p)))

(provide 'pro-compat)

;;; pro-compat.el ends here
