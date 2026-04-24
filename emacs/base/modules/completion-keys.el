;;; completion-keys.el --- Keybindings for cape/corfu/consult helpers -*- lexical-binding: t; -*-
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

(with-eval-after-load 'keys
  (when (fboundp 'pro/register-module-keys)
    (condition-case err
        (pro/register-module-keys 'completion pro/completion-suggested-keys)
      (error (message "pro: failed to register completion suggested keys: %S" err)))))

  (when (fboundp 'pro/export-registered-keys-to-org)
    ;; Export suggested keys to an org fragment for review on demand
    (pro/export-registered-keys-to-org)))

(provide 'completion-keys)

;;; completion-keys.el ends here
