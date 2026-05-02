#! /usr/bin/env emacs --script
;; Script: check-elisp-parens.el
;; Usage: emacs --script scripts/check-elisp-parens.el -- --dir=emacs --fix
;; Scans .el files, reports unbalanced parentheses and can append missing closing
;; parens at EOF when safe (positive net open paren count).

(require 'cl-lib)

(defvar cep--dir "emacs"
  "Directory to scan for .el files.")

(defvar cep--fix nil
  "If non-nil, try to automatically fix safe cases by appending ')'s.")

(defvar cep--max-fix 10
  "Maximum number of parens to append automatically. Prevents large dangerous edits.")

(defun cep--parse-args ()
  "Parse command-line args from `command-line-args-left'.
Accepts --dir=PATH and --fix (flag)."
  (dolist (arg command-line-args-left)
    (cond
     ((string-prefix-p "--dir=" arg)
      (setq cep--dir (substring arg (length "--dir="))))
     ((string-prefix-p "--max-fix=" arg)
      (let ((n (string-to-number (substring arg (length "--max-fix=")))))
        (when (> n 0) (setq cep--max-fix n))))
      ((string= "--fix" arg)
       (setq cep--fix t))
     (t
      ;; ignore unknown args
      )))
  (when (and (string= cep--dir "") (getenv "PWD"))
    (setq cep--dir (getenv "PWD"))))

(defun cep--el-files (dir)
  "Return list of .el files under DIR (recursive)."
  (when (file-directory-p dir)
    (let ((default-directory dir))
      (directory-files-recursively dir "\\.el$"))))

(defun cep--net-paren-balance (buffer)
  "Compute net '(' minus ')' in BUFFER ignoring strings/comments.
Returns integer (positive => missing closing parens, negative => extra closing parens).
This scans occurrences of '(' and ')' and uses syntax-ppss to skip strings/comments." 
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-min))
      (let ((balance 0))
        (while (re-search-forward "[()]" nil t)
          (let* ((pos (match-beginning 0))
                 (syntax (syntax-ppss pos))
                 (in-string (nth 3 syntax))
                 (in-comment (nth 4 syntax)))
            (unless (or in-string in-comment)
              (let ((ch (char-after pos)))
                (cond ((eq ch ?\() (cl-incf balance))
                      ((eq ch ?\)) (cl-decf balance)))))))
        balance))))

(defun cep--check-file (file)
  "Check FILE for paren balance. Return plist with :file :ok :balance :fixed :error.
:fixed is t if we auto-fixed the file. :error contains error message if any." 
  (let ((buf (get-buffer-create "*cep-temp*"))
        (res (list :file file :ok t :balance 0 :fixed nil :error nil)))
    (with-current-buffer buf
      (erase-buffer)
      (insert-file-contents file)
      (emacs-lisp-mode)
      (condition-case err
          (let ((balance (cep--net-paren-balance buf)))
            (setq res (plist-put res :balance balance))
            (when (/= balance 0)
              (setq res (plist-put res :ok nil))
              (if (and cep--fix (> balance 0) (<= balance cep--max-fix))
                  (progn
                    ;; append missing closing parens at EOF, but only up to max
                    (goto-char (point-max))
                    (unless (bolp) (insert "\n"))
                    (insert (make-string balance ?\)))
                    (write-region (point-min) (point-max) file nil 'silent)
                    (setq res (plist-put res :fixed t)))
                ;; not fixable automatically
                (when (and cep--fix (> balance cep--max-fix))
                  (setq res (plist-put res :error (format "balance %d > max-fix %d" balance cep--max-fix))))))
        (error
         (setq res (plist-put res :ok nil))
         (setq res (plist-put res :error (format "%S" err)))))
      )
    (when (buffer-live-p buf) (kill-buffer buf))
    res))

(defun cep--report (results)
  "Print a concise machine-readable report from RESULTS (list of plists)." 
  (let ((bad 0))
    (dolist (r results)
      (let ((file (plist-get r :file))
            (ok (plist-get r :ok))
            (bal (plist-get r :balance))
            (fixed (plist-get r :fixed))
            (err (plist-get r :error)))
        (if ok
            (princ (format "OK  %s\n" file))
          (cl-incf bad)
          (princ (format "BAD %s balance=%d%s%s%s\n"
                         file bal
                         (if fixed " FIXED" "")
                         (if err (format " ERROR=%s" err) "")
                         (if (and (not fixed) (> bal 0)) " (can-fix-by-appending)" ""))))))
    bad))

(defun main ()
  (cep--parse-args)
  (let* ((dir cep--dir)
         (files (or (cep--el-files dir) (list)))
         (results nil))
    (dolist (f files)
      (push (cep--check-file f) results))
    (let ((bad (cep--report (nreverse results))))
      (when (> bad 0)
        ;; exit with non-zero so CI can detect issues when not fixed
        (kill-emacs 2))
      (kill-emacs 0))))

(when (equal (file-name-nondirectory (or load-file-name (buffer-file-name)))
             "check-elisp-parens.el")
  (main))
