;;; fix-pending.el --- Try to resolve remaining pro-keys pending bindings -*- lexical-binding: t; -*-
;; Usage: emacs --batch -l emacs/base/init.el -l emacs/base/tools/fix-pending.el

(message "fix-pending: start")

;; Mapping of commands to explicit feature names to require.
(defvar fix-pending-mapping
  '((cape-keyword . (cape-keyword cape))
    (cape-symbol . (cape))
    (exwm-workspace-switch . (exwm))
    (exwm-reset . (exwm))
    (eldoc-box-help-at-point . (eldoc-box eldoc))
    (consult-imenu . (consult imenu))
    (pro-packages-menu . (pro-packages))
    (pro-packages-install . (pro-packages))
    (pro-packages-install-vc . (pro-packages))
    (pro-packages-refresh . (pro-packages))
    (pro-packages-upgrade-all . (pro-packages))
    (pro-packages-upgrade-built-ins . (pro-packages)))
  "Alist: command-symbol -> list of features to attempt to require.")

(defun fix-pending--ensure-features (feats)
  "Attempt to require each feature in FEATS, returning alist (feat . provided?)." 
  (mapcar (lambda (f) (cons f (condition-case _ (require f nil t) (error nil)))) feats))

(when (boundp 'pro-keys-pending-bindings)
  (let ((still '()) )
    (dolist (entry pro-keys-pending-bindings)
      (pcase entry
        (`(:global ,key ,cmd)
         (let ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd))))
               (cands (or (alist-get (if (symbolp cmd) cmd (intern (format "%s" cmd))) fix-pending-mapping)
                          (list (if (symbolp cmd) cmd (intern (format "%s" cmd)))))))
           (message "fix-pending: trying %S for command %S (key %s)" cands sym key)
           (dolist (f cands)
             (message "  require %s -> %S" f (condition-case _ (require f nil t) (error nil))))
           ;; attempt apply
           (when (fboundp 'pro-keys-apply-pending)
             (ignore-errors (pro-keys-apply-pending)))
           (unless (and (symbolp sym) (fboundp sym)) (push entry still))))
        (`(:exwm ,key ,cmd)
         (let ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd)))))
           (if (display-graphic-p)
               (let ((cands (or (alist-get sym fix-pending-mapping) (list 'exwm))))
                 (dolist (f cands) (message "  require %s -> %S" f (condition-case _ (require f nil t) (error nil))))
                 (when (fboundp 'pro-keys-apply-pending) (ignore-errors (pro-keys-apply-pending))))
             (message "fix-pending: skipping EXWM require in headless mode for %S" sym))
           (unless (and (symbolp sym) (fboundp sym)) (push entry still))))
        (_ (push entry still))))
    (message "fix-pending: remaining pending count after attempts: %d" (length still))
    (dolist (e still) (message " STILL: %S" e))))

(message "fix-pending: done")
