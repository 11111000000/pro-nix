;;; test-haskell.el --- ERT tests for pro-haskell -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defvar test-haskell--module-file
  (expand-file-name "pro-haskell.el"
                    (expand-file-name "../modules"
                                      (file-name-directory
                                       (or load-file-name buffer-file-name))))
  "Path to the pro-haskell.el module under test.")

(unless (featurep 'pro-haskell)
  (load-file test-haskell--module-file))

(ert-deftest test-haskell/module-loads-without-error ()
  "Loading pro-haskell.el must not error even when haskell-mode is missing."
  (should (featurep 'pro-haskell)))

(ert-deftest test-haskell/auto-mode-alist-contains-haskell-extensions ()
  "`pro-haskell' must register .hs, .lhs, .cabal, .stack.yaml in auto-mode-alist."
  (let ((targets '(("\\.hs\\'" . haskell-mode)
                   ("\\.lhs\\'" . literate-haskell-mode)
                   ("\\.cabal\\'" . haskell-cabal-mode)
                   ("\\.stack\\.yaml\\'" . haskell-stack-yaml-mode))))
    (dolist (target targets)
      (let* ((regex (car target))
             (expected (cdr target))
             (entry (assoc regex auto-mode-alist))
             (actual (and (consp entry) (cdr entry))))
        (should entry)
        (should (eq actual expected))))))

(ert-deftest test-haskell/lsp-server-program-customizable ()
  "`pro-haskell-lsp-server-program' must default to HLS wrapper and be customizable."
  (should (consp pro-haskell-lsp-server-program))
  (should (equal (car pro-haskell-lsp-server-program) "haskell-language-server-wrapper"))
  (should (member "--lsp" pro-haskell-lsp-server-program))
  (should (custom-variable-p 'pro-haskell-lsp-server-program)))

(ert-deftest test-haskell/eglot-server-programs-registers-haskell ()
  "After loading eglot, `pro-haskell' must register HLS as the haskell LSP."
  (skip-unless (fboundp 'eglot-server-programs))
  (pro-haskell--register-eglot-server)
  (let ((haskell-entry (assq 'haskell-mode eglot-server-programs))
        (literate-entry (assq 'literate-haskell-mode eglot-server-programs)))
    (should haskell-entry)
    (should literate-entry)
    (should (equal (cdr haskell-entry) pro-haskell-lsp-server-program))))

(ert-deftest test-haskell/setup-sets-indent-and-tab-width ()
  "`pro-haskell-setup' must disable tabs and set width 2 in the current buffer."
  (with-temp-buffer
    (pro-haskell-setup)
    (should (eq indent-tabs-mode nil))
    (should (eq tab-width 2))))

(ert-deftest test-haskell/format-buffer-without-fourmolu-is-friendly ()
  "When fourmolu is not on PATH, `pro-haskell-format-buffer' must not error
and must surface a friendly message."
  (skip-unless (fboundp 'haskell-mode))
  (with-temp-buffer
    (delay-mode-hooks (haskell-mode))
    (let ((last-message nil))
      (cl-letf (((symbol-function 'executable-find)
                 (lambda (_name) nil))
                ((symbol-function 'message)
                 (lambda (fmt &rest args)
                   (setq last-message (apply #'format fmt args))))))
        (pro-haskell-format-buffer)
        (should (string-match-p "fourmolu not found" last-message)))))

(ert-deftest test-haskell/lint-without-hlint-is-friendly ()
  "When hlint is not on PATH, `pro-haskell-lint' must not error and must
surface a friendly message."
  (skip-unless (fboundp 'haskell-mode))
  (with-temp-buffer
    (delay-mode-hooks (haskell-mode))
    (let ((last-message nil))
      (cl-letf (((symbol-function 'executable-find)
                 (lambda (_name) nil))
                ((symbol-function 'message)
                 (lambda (fmt &rest args)
                   (setq last-message (apply #'format fmt args))))))
        (pro-haskell-lint)
        (should (string-match-p "hlint not found" last-message)))))

(ert-deftest test-haskell/format-buffer-rejects-non-haskell-buffer ()
  "`pro-haskell-format-buffer' must signal a user-error outside haskell-mode."
  (with-temp-buffer
    (insert "not haskell")
    (should-error (pro-haskell-format-buffer) :type 'user-error)))

(ert-deftest test-haskell/load-buffer-rejects-non-haskell-buffer ()
  "`pro-haskell-load-buffer' must signal a user-error outside haskell-mode."
  (with-temp-buffer
    (insert "not haskell")
    (should-error (pro-haskell-load-buffer) :type 'user-error)))

(ert-deftest test-haskell/hooks-wired-for-haskell-mode ()
  "`pro-haskell-setup' must be on `haskell-mode-hook' and
`literate-haskell-mode-hook'."
  (should (memq #'pro-haskell-setup haskell-mode-hook))
  (should (memq #'pro-haskell-setup literate-haskell-mode-hook)))

(ert-deftest test-haskell/ensure-mode-does-not-throw-when-missing ()
  "`pro-haskell--ensure-mode' must return nil (not throw) when haskell-mode
is not provided."
  (let ((pro-haskell--mode-available nil)
        (pro-packages-decisions nil)
        (pro-packages-auto-install-allowlist nil))
    (cl-letf (((symbol-function 'pro--package-runtime-available-p)
               (lambda (_pkg) nil))
              ((symbol-function 'pro/packages-ensure)
               (lambda (_pkg &optional _allow) nil))
              ((symbol-function 'require)
               (lambda (_feat &optional _f _err) nil)))
      (should (eq (pro-haskell--ensure-mode) nil)))))
