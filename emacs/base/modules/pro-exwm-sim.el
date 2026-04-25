;;; pro-exwm-sim.el --- EXWM input simulation helpers (pro-nix implementation) -*- lexical-binding: t; -*-
;; Safe, defensive helpers for installing EXWM simulation keys and macros.

(require 'cl-lib)

(defvar pro/exwm-default-simulation-keys
  '(([?\C-b] . left)
    ([?\M-b] . C-left)
    ([?\C-f] . right)
    ([?\M-f] . C-right)
    ([?\C-p] . up)
    ([?\C-n] . down)
    ([?\C-a] . home)
    ([?\C-e] . end)
    ([?\M-v] . prior)
    ([?\C-v] . next)
    ([?\C-d] . ?\C-x)
    ([?\M-d] . (C-S-right delete))
    ([?\M-y] . ?\C-c)
    ([?\M-w] . ?\C-c)
    ([?\C-y] . ?\C-v)
    ([?\C-s] . ?\C-f))
  "Default key simulation mapping for EXWM (char -> target key/symbol).")

(defmacro pro/exwm-input-set-keys (&rest key-bindings)
  "Set EXWM input simulation keys.
KEY-BINDINGS is a list of ("key" . command) pairs similar to exwm-input-set-key.
This macro is a tiny wrapper to avoid direct dependency when exwm is not present." 
  `(when (fboundp 'exwm-input-set-key)
     (dolist (kb ',key-bindings)
       (cl-destructuring-bind (key cmd) kb
         (exwm-input-set-key (kbd key) cmd)))))

(defun pro/exwm-apply-default-simulation-keys ()
  "Apply `pro/exwm-default-simulation-keys` using `exwm-input-set-key` where available." 
  (interactive)
  (when (fboundp 'exwm-input-set-key)
    (dolist (pair pro/exwm-default-simulation-keys)
      (let ((from (car pair)) (to (cdr pair)))
        (condition-case _err
            (exwm-input-set-key from to)
          (error (message "pro/exwm: failed to set sim key %s -> %s" from to)))))))

(provide 'pro-exwm-sim)

;;; pro-exwm-sim.el ends here
