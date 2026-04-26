;; Run ERT tests distributed under emacs/base/tests
(setq ert-runner-options '( :reporter ert-progress))
(let ((test-dir (expand-file-name "emacs/base/tests" "")))
  (when (file-directory-p test-dir)
    (dolist (f (directory-files test-dir t "^test-.*\\.el$"))
      (load f nil t))))
(ert-run-tests-batch-and-exit)
