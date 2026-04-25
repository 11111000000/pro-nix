;;; pro-completion-keys.el --- Keybindings for cape/corfu/consult helpers -*- lexical-binding: t; -*-
;; Safe, lazy keybinding file: binds C-c o <letter> to cape backends

;; Instead of binding global keys directly, publish suggested keys for
;; keys loader. Modules must not call global-set-key on top-level.
(defvar pro/completion-suggested-keys
  '( ("C-c o f" . cape-file)
     ("C-c o d" . cape-dabbrev)
     ("C-c o h" . cape-history)
     ("C-c o k" . cape-keyword)
     ("C-c o s" . cape-symbol)
     ("C-c o a" . cape-abbrev)
     ("C-c o ." . completion-at-point)
     ("C-c y y" . consult-yasnippet) )
  "Suggested global keys for completion (CAPE/consult-yasnippet).")

(with-eval-after-load 'pro-keys
  (when (fboundp 'pro/register-module-keys)
    ;; Write a small diagnostic file before attempting registration so the
    ;; error handler can remain simple and avoid referencing the handler
    ;; variable which in some early startup contexts can be unbound.
    (ignore-errors
      (with-temp-file "/tmp/pro-register-completion.log"
        (insert (format "CALL: time=%s module=completion\n" (current-time-string)))
        (prin1 pro/completion-suggested-keys (current-buffer))))
    (condition-case _err
        (pro/register-module-keys 'completion pro/completion-suggested-keys)
      (error (message "pro: failed to register completion suggested keys (see /tmp/pro-register-completion.log)"))))

  (when (fboundp 'pro/export-registered-keys-to-org)
    ;; Export suggested keys to an org fragment for review on demand.
    (pro/export-registered-keys-to-org)))

;; Provide both the prefixed and unprefixed feature names for compatibility
;; with user-managed modules that may `require` the unprefixed name.
(provide 'pro-completion-keys)
(provide 'pro-completion-keys)

;;; pro-completion-keys.el ends here
