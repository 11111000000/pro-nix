;;; check-pending-ops.el --- Deep check of pending bindings and package operability
;; Run from repo root after loading init:
;; emacs --batch -l emacs/base/init.el -l emacs/base/tools/check-pending-ops.el

(message "check-pending-ops: start")

(defvar check-pending-ops-candidates
  '((pro-packages-menu . (pro-packages))
    (treemacs . (treemacs))
    (projectile-find-file . (projectile))
    (projectile-switch-project . (projectile))
    (er/expand-region . (expand-region))
    (consult-eglot-symbols . (consult eglot))
    (consult-yasnippet . (consult yasnippet))
    (cape-abbrev . (cape))
    (cape-symbol . (cape))
    (cape-keyword . (cape))
    (cape-history . (cape))
    (cape-dabbrev . (cape))
    (cape-file . (cape))
    (exwm-workspace-switch . (exwm))
    (exwm-reset . (exwm))
    (eldoc-box-help-at-point . (eldoc-box eldoc))
    (consult-ripgrep . (consult ripgrep))
    (consult-goto-line . (consult))
    (consult-imenu . (consult imenu)))
  "Alist mapping command -> candidate features/packages to check.")

(defun check-pending-ops--try-features (feats)
  "Try require each feature in FEATS and return alist (feat . provided?)." 
  (mapcar (lambda (f) (cons f (condition-case _ (require f nil t) (error nil)))) feats))

(when (boundp 'pro-keys-pending-bindings)
  (let ((results '()) (todo (copy-sequence pro-keys-pending-bindings)))
    (dolist (entry todo)
      (pcase entry
        (`(:global ,key ,cmd)
         (let* ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd))))
                (cands (or (alist-get sym check-pending-ops-candidates) (list (intern (car (split-string (symbol-name sym) "-"))))))
                (trial (check-pending-ops--try-features cands)))
           (push (list :entry entry :sym sym :trial trial :fboundp (fboundp sym)) results)))
        (`(:exwm ,key ,cmd)
         (let* ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd))))
                (cands (or (alist-get sym check-pending-ops-candidates) (list 'exwm)))
                (trial (check-pending-ops--try-features cands)))
           (push (list :entry entry :sym sym :trial trial :fboundp (fboundp sym) :graphical (display-graphic-p)) results)))
        (`(:org ,key ,cmd)
         (let* ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd))))
                (cands (or (alist-get sym check-pending-ops-candidates) (list 'org)))
                (trial (check-pending-ops--try-features cands)))
           (push (list :entry entry :sym sym :trial trial :fboundp (fboundp sym)) results)))
        (_ (push (list :entry entry :note "unknown entry type") results))))

    ;; Print report
    (princ "Pending bindings deep check report:\n")
    (dolist (r (nreverse results))
      (let ((entry (plist-get r :entry)) (sym (plist-get r :sym)) (trial (plist-get r :trial)) (fboundp (plist-get r :fboundp)))
        (princ (format "ENTRY: %S\n" entry))
        (princ (format "  command symbol: %S fboundp=%S\n" sym fboundp))
    (princ "  candidate requires:\n")
        (dolist (pair trial)
          (princ (format "    %s -> %S\n" (car pair) (cdr pair))))
        (when (and (not fboundp) (not (cl-find-if #'cdr trial)))
          (princ "  RECOMMEND: install one of the candidate packages or enable graphical session (for EXWM/eldoc-box).\n"))
        (princ "\n")))
    (princ "End of report\n")))

(message "check-pending-ops: done")
