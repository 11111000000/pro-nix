;;; test-pending-bindings.el --- Ensure pro-keys pending bindings resolved -*- lexical-binding: t; -*-
;; This test ensures that after attempting to install required packages and
;; applying pending keybindings, no non-GUI pending bindings remain. GUI-only
;; bindings (like EXWM) are permitted to remain in headless runs.

(require 'ert)

(defun test-pending--candidate-features (sym)
  "Return candidate feature symbols for command SYM (heuristic)." 
  (let ((s (symbol-name sym)))
    (cond
     ((string-prefix-p "cape-" s) '(cape))
     ((string-prefix-p "consult-" s) '(consult))
     ((string-prefix-p "projectile-" s) '(projectile))
     ((string-prefix-p "treemacs" s) '(treemacs))
     ((string-prefix-p "exwm-" s) '(exwm))
     ((string-match-p "eldoc" s) '(eldoc-box eldoc))
     ((string-match-p "imenu" s) '(consult imenu))
     (t (list (intern (car (split-string s "-"))))))))

(ert-deftest pro-smoke/pending-bindings-resolved ()
  "Ensure no non-GUI pending bindings remain after install attempts.

Procedure:
- Ensure required packages via `pro-packages-ensure-required'.
- Run fixer `pro-keys-apply-pending' (via fix-pending helper).
- Fail if any pending binding remains whose candidate features are not
  available and are not GUI-only (exwm/eldoc-box).
"
  (unless (boundp 'pro-keys-pending-bindings)
    (should nil))

  ;; Attempt to ensure packages and apply pendings
  (when (fboundp 'pro-packages-ensure-required) (pro-packages-ensure-required))
  (when (fboundp 'pro-keys-apply-pending) (pro-keys-apply-pending))

  (let* ((pending (or (and (boundp 'pro-keys-pending-bindings) pro-keys-pending-bindings) '()))
         (allowed-gui '(exwm eldoc-box))
         (bad '()))
    (dolist (e pending)
      (pcase e
        (`(:global ,key ,cmd)
         (let* ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd))))
                (cands (test-pending--candidate-features sym))
                (ok (seq-some (lambda (f) (or (featurep f) (pro--package-provided-p f) (package-installed-p f))) cands)))
           (unless ok (push e bad))))
        (`(:exwm ,key ,cmd)
         ;; GUI-only; allowed in headless
         (unless (display-graphic-p)
           ;; if headless, exwm remains allowed; skip
           nil))
        (_ (push e bad))))

    (when bad
      (should (null bad)))))

;;; test-pending-bindings.el ends here
