;;; pending-report.el --- Detailed report for pro-keys pending bindings -*- lexical-binding: t; -*-
;; Usage: emacs --batch -l emacs/base/init.el -l emacs/base/tools/pending-report.el

(message "pending-report: start")

(defun pending--candidates (cmd)
  "Return candidate features/packages for command symbol CMD.
This is heuristic mapping used to diagnose why a binding remains pending." 
  (let ((s (if (symbolp cmd) (symbol-name cmd) (format "%s" cmd))))
    (cond
     ((string-prefix-p "cape-" s) (list :features (list 'cape-keyword 'cape) :pkgs (list 'cape)))
     ((string-prefix-p "consult-" s) (list :features (list 'consult) :pkgs (list 'consult)))
     ((string-prefix-p "projectile-" s) (list :features (list 'projectile) :pkgs (list 'projectile)))
     ((string-prefix-p "treemacs" s) (list :features (list 'treemacs) :pkgs (list 'treemacs)))
     ((string-prefix-p "eglot" s) (list :features (list 'eglot) :pkgs (list 'eglot)))
     ((string-prefix-p "exwm-" s) (list :features (list 'exwm) :pkgs (list 'exwm)))
     ((string-match-p "eldoc" s) (list :features (list 'eldoc 'eldoc-box) :pkgs (list 'eldoc-box)))
     ((string-match-p "imenu" s) (list :features (list 'consult 'imenu) :pkgs (list 'consult)))
     (t (list :features (list (intern s)) :pkgs (list (intern (car (split-string s "-"))))))))

(defun pending--check-entry (entry)
  "Check one pending ENTRY and print diagnostics." 
  (pcase entry
    (`(:global ,key ,cmd)
     (let* ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd))))
            (cands (pending--candidates sym)))
       (princ (format "ENTRY: global %s -> %S\n" key sym))
       (princ (format "  fboundp: %S\n" (fboundp sym)))
       (dolist (f (plist-get cands :features))
         (princ (format "  feature %s: featurep=%S require-able=%S\n" f (featurep f) (condition-case _ (require f nil t) (error nil)))))
       (dolist (p (plist-get cands :pkgs))
         (princ (format "  package %s: installed=%S\n" p (condition-case _ (package-installed-p p) (error nil)))))
       (princ "\n")))
    (`(:exwm ,key ,cmd)
     (let ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd)))) (disp (display-graphic-p)))
       (princ (format "ENTRY: exwm %s -> %S (display-graphic-p=%S)\n" key sym disp))
       (princ (format "  fboundp: %S\n" (fboundp sym)))
       (when (not disp)
         (princ "  Note: EXWM functions require a graphical X session; in headless mode these will be unavailable.\n"))
       (princ "\n")))
    (`(:org ,key ,cmd)
     (let ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd)))))
       (princ (format "ENTRY: org %s -> %S\n" key sym))
       (princ (format "  fboundp: %S\n" (fboundp sym)))
       (princ "\n")))
    (_ (princ (format "ENTRY: unknown %S\n" entry)))))

(when (boundp 'pro-keys-pending-bindings)
  (princ (format "Pending bindings count: %d\n" (length pro-keys-pending-bindings)))
  (dolist (e pro-keys-pending-bindings)
    (pending--check-entry e)))

(message "pending-report: done")
