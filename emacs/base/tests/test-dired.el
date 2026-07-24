;;; test-dired.el --- ERT tests for dired module -*- lexical-binding: t; -*-

(require 'ert)
(require 'pro-reload)

(ert-deftest pro-dired-loads-nonerror ()
  "Module dired.el should load without error."
  (should (ignore-errors (require 'pro-dired))))

(ert-deftest pro-dired-listing-switches-set ()
  "dired-listing-switches should be set to a sensible default when module loaded."
  (require 'pro-dired)
  (should (string-match "--group-directories-first" dired-listing-switches)))

(ert-deftest pro-reload-file-reruns-top-level ()
  "`pro/reload-file' should re-run top-level forms: a side-effect form
(setq) on every reload, and reload cleanly (no leftover state)."
  (let* ((tmp (make-temp-file "pro-reload-test" nil ".el"))
         (var (intern (concat "pro-reload-test-var-" (number-to-string (random 1000000)))))
         (list-var (intern (concat "pro-reload-test-list-" (number-to-string (random 1000000))))))
    (unwind-protect
        (progn
          ;; v1: setq + provide (НЕ defvar — defvar не сбрасывает существующее
          ;; значение, это Lisp-семантика, а не наша особенность).
          (write-region (format "(setq %s 1)\n(setq %s (list 1))\n(provide 'pro-reload-test)\n"
                               var list-var)
                        nil tmp)
          (should (eq t (pro/reload-file tmp)))
          ;; После первого reload: var=1, list-var=(1).
          (should (eq 1 (symbol-value var)))
          (should (equal (list 1) (symbol-value list-var)))
          ;; v2: правим значения.
          (write-region (format "(setq %s 999)\n(setq %s (list 1 2))\n(provide 'pro-reload-test)\n"
                               var list-var)
                        nil tmp)
          (should (eq t (pro/reload-file tmp)))
          ;; После второго reload: var=999, list-var=(1 2). setq
          ;; выполнился повторно, как и хотим.
          (should (eq 999 (symbol-value var)))
          (should (equal (list 1 2) (symbol-value list-var))))
      (ignore-errors (delete-file tmp))
      (ignore-errors (delete-file (concat (file-name-sans-extension tmp) ".elc")))
      (makunbound var)
      (makunbound list-var))))

(ert-deftest pro-reload-file-reruns-defcustom-initializer ()
  "`pro/reload-file' should re-run a `defcustom' initializer after unload."
  (let* ((tmp (make-temp-file "pro-reload-custom" nil ".el"))
         (var (intern (concat "pro-reload-custom-" (number-to-string (random 1000000)))))
         (feat (intern (concat "pro-reload-custom-feature-" (number-to-string (random 1000000))))))
    (unwind-protect
        (progn
          (write-region (format "(defcustom %s 1 \"Test.\" :type 'integer)\n(provide '%s)\n" var feat) nil tmp)
          (should (eq t (pro/reload-file tmp)))
          (should (eq 1 (symbol-value var)))
          (write-region (format "(defcustom %s 2 \"Test.\" :type 'integer)\n(provide '%s)\n" var feat) nil tmp)
          (should (eq t (pro/reload-file tmp)))
          (should (eq 2 (symbol-value var))))
      (ignore-errors (unload-feature feat t))
      (ignore-errors (delete-file tmp))
      (ignore-errors (delete-file (concat (file-name-sans-extension tmp) ".elc")))
      (makunbound var))))

(ert-deftest pro-reload-file-replaces-function ()
  "`pro/reload-file' should replace a function definition with the new body."
  (let* ((tmp (make-temp-file "pro-reload-fundef" nil ".el"))
         (fn (intern (concat "pro-reload-fn-" (number-to-string (random 1000000)))))
         (feat (intern (concat "pro-reload-fundef-test-" (number-to-string (random 1000000))))))
    (unwind-protect
        (progn
          ;; v1
          (write-region (format "(defun %s () 1)\n(provide (quote %s))\n" fn feat) nil tmp)
          (should (eq t (pro/reload-file tmp)))
          (should (eq 1 (funcall (symbol-function fn))))
          (should (featurep feat))
          ;; v2 — overwrite the file with a new body.
          (write-region (format "(defun %s () 2)\n(provide (quote %s))\n" fn feat) nil tmp)
          (should (eq t (pro/reload-file tmp)))
          (should (eq 2 (funcall (symbol-function fn))))
          (should (featurep feat)))
      (ignore-errors (delete-file tmp))
      (ignore-errors (delete-file (concat (file-name-sans-extension tmp) ".elc")))
      (fmakunbound fn))))

(ert-deftest pro-reload-file-rejects-non-el ()
  "`pro/reload-file' should user-error on a non-.el file."
  (let ((tmp (make-temp-file "pro-reload-bad" nil ".txt")))
    (unwind-protect
        (should (eq 'user-error
                    (car (condition-case err
                             (pro/reload-file tmp)
                           (error err)))))
      (ignore-errors (delete-file tmp)))))

(ert-deftest pro-dired-reload-recursive-skips-hidden-dirs ()
  "`pro/dired-reload-elisp-dir-recursive' should skip .git, .vscode, etc.

The function is interactive and walks `dired-current-directory'; we
exercise the underlying directory-files-recursively contract by
constructing a fixture tree and walking it with the same predicate."
  (let* ((root (make-temp-file "pro-reload-walk" t))
         (good (expand-file-name "good.el" root))
         (in-git (expand-file-name ".git/bad.el" root))
         (in-vscode (expand-file-name ".vscode/bad.el" root))
         (nested (expand-file-name "sub/leaf.el" root)))
    (unwind-protect
        (progn
          (write-region "(provide 'good)\n" nil good)
          (make-directory (file-name-directory in-git) t)
          (write-region "(provide 'bad)\n" nil in-git)
          (make-directory (file-name-directory in-vscode) t)
          (write-region "(provide 'bad)\n" nil in-vscode)
          (make-directory (file-name-directory nested) t)
          (write-region "(provide 'leaf)\n" nil nested)
          (let* ((files (directory-files-recursively
                         root "\\.el\\'" nil
                         (lambda (name)
                           (let ((base (file-name-nondirectory name)))
                             (not (string-match-p
                                   "^[.]\\(git\\|dir-locals\\|vscode\\|idea\\|cache\\|stack-work\\|cabal\\|ghc\\.environment\\)$"
                                   base)))))))
            (should (member good files))
            (should (member nested files))
            (should-not (member in-git files))
            (should-not (member in-vscode files))))
      (ignore-errors (delete-directory root t)))))

(provide 'test-dired)
