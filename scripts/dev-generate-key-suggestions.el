;; Generate key suggestions by reading pro/register-module-keys sexps from modules
;; Usage: emacs -Q --batch -l scripts/generate-key-suggestions.el --eval "(generate-keys \"/path/to/repo\" \"/tmp/out.org\")"

(require 'subr-x)

(defun pro--read-next-sexp-from-buffer ()
  "Read next sexp from current buffer at point. Return it or nil on error." 
  (condition-case err
      (let ((read-data (read (current-buffer)))) read-data)
    (end-of-file nil)
    (error nil)))

(defun generate-keys (repo-root out-file)
  "Scan modules in REPO-ROOT/emacs/base/modules for pro/register-module-keys and write OUT-FILE." 
  (let* ((modules-dir (expand-file-name "emacs/base/modules" repo-root))
         (files (when (file-directory-p modules-dir) (directory-files modules-dir t "\\.el$"))))
    (with-temp-file out-file
      (insert (format "# Generated suggestions at %s\n\n" (current-time-string)))
      (dolist (f files)
        (with-temp-buffer
          (insert-file-contents f)
          (goto-char (point-min))
          (while (search-forward "(pro/register-module-keys" nil t)
            (backward-char (length "(pro/register-module-keys"))
            (let ((sexp (pro--read-next-sexp-from-buffer)))
              (when (and (listp sexp) (eq (car sexp) 'pro/register-module-keys))
                (let ((mod (cadr sexp)) (alist (caddr sexp)))
                  (insert (format "# PRO-MODULE: %s\n" (prin1-to-string mod)))
                  (when (and (listp alist))
                    (dolist (pair alist)
                      (when (and (consp pair) (stringp (car pair)))
                        (insert (format "| Suggested | %s | %s | suggested from %s |\n"
                                        (car pair) (prin1-to-string (cdr pair)) (prin1-to-string mod)))))))))))))

(provide 'generate-key-suggestions)
