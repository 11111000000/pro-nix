;;; test-tabs.el --- ERT tests for pro-tabs tab-line keybindings -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

;; `tab-line-mode' is a minor-mode variable that Emacs only defines when
;; `tab-line.el' is loaded. Our tests run with `emacs -Q' (no tab-line),
;; so the symbol is unbound. `pro-tabs--line-tabs' reads it with
;; `(symbol-value ...)', which is a DYNAMIC lookup. With
;; `lexical-binding: t' in this test file, an unbound `let' binding
;; would be LEXICAL and invisible to `symbol-value'. Declaring the
;; variable as special makes `let' create a dynamic binding.
(defvar tab-line-mode nil
  "Stub of the `tab-line-mode' minor-mode variable for headless tests.")
(make-variable-buffer-local 'tab-line-mode)

(defvar test-tabs--module-file
  (expand-file-name "pro-tabs.el"
                    (expand-file-name "../modules"
                                      (file-name-directory
                                       (or load-file-name buffer-file-name))))
  "Path to the pro-tabs.el module under test.")

(unless (featurep 'pro-tabs-integration)
  ;; Use `load-file' (not `require') to avoid the recursive-load trap:
  ;; `(require 'pro-tabs ...)' inside the module would resolve to this
  ;; file and recurse in environments where the submodule is not on
  ;; the load path. `load-file' loads the file once and trusts that
  ;; the existing in-file conditional handles the submodule lookup.
  (load-file test-tabs--module-file))

(ert-deftest pro-tabs/--line-tabs-returns-nil-without-tab-line ()
  "`pro-tabs--line-tabs' should be nil when tab-line-mode is off."
  (should (fboundp 'pro-tabs--line-tabs))
  (with-temp-buffer
    (let ((tab-line-mode nil))
      (should (not (pro-tabs--line-tabs))))))

(ert-deftest pro-tabs/--line-tabs-returns-nil-when-no-tabs ()
  "`pro-tabs--line-tabs' should be nil when tab-line-mode is on but no tabs."
  (let ((buf1 (generate-new-buffer " *test-tabs-1*")))
    (with-temp-buffer
      (let ((tab-line-mode t))
        (cl-letf (((symbol-function 'tab-line-tabs-window-buffers)
                   (lambda () nil)))
          (should (not (pro-tabs--line-tabs))))))))

(ert-deftest pro-tabs/--line-tabs-returns-tabs-when-present ()
  "`pro-tabs--line-tabs' should be non-nil when tab-line-mode is on and tabs exist."
  (let ((buf1 (generate-new-buffer " *test-tabs-1*"))
        (buf2 (generate-new-buffer " *test-tabs-2*")))
    (with-temp-buffer
      (let ((tab-line-mode t))
        (cl-letf (((symbol-function 'tab-line-tabs-window-buffers)
                   (lambda () (list buf1 buf2))))
          (should (pro-tabs--line-tabs)))))))

(ert-deftest pro-tabs/line-next-is-noop-without-tab-line ()
  "`pro-tabs-line-next' should be a no-op (and not call tab-line) when
no tab-line tabs are present. This is the key behavior: C-<tab> must
NOT fall through to `tab-bar' switching."
  (with-temp-buffer
    (let ((tab-line-mode nil)
          (tab-line-called nil)
          (tab-bar-called nil))
      (cl-letf (((symbol-function 'tab-line-switch-to-next-tab)
                 (lambda (&rest _) (interactive) (setq tab-line-called t)))
                ((symbol-function 'tab-bar-cycle-select-tab)
                 (lambda (&rest _) (interactive) (setq tab-bar-called t))))
        (condition-case nil
            (pro-tabs-line-next)
          (wrong-type-argument))
        (should (not tab-line-called))
        (should (not tab-bar-called))))))

(ert-deftest pro-tabs/line-prev-is-noop-without-tab-line ()
  "`pro-tabs-line-prev' should be a no-op (and not call tab-line) when
no tab-line tabs are present. C-S-<tab> must NOT fall through to tab-bar."
  (with-temp-buffer
    (let ((tab-line-mode nil)
          (tab-line-called nil)
          (tab-bar-called nil))
      (cl-letf (((symbol-function 'tab-line-switch-to-prev-tab)
                 (lambda (&rest _) (interactive) (setq tab-line-called t)))
                ((symbol-function 'tab-bar-cycle-select-tab)
                 (lambda (&rest _) (interactive) (setq tab-bar-called t))))
        (condition-case nil
            (pro-tabs-line-prev)
          (wrong-type-argument))
        (should (not tab-line-called))
        (should (not tab-bar-called))))))

(ert-deftest pro-tabs/line-next-calls-tab-line-when-present ()
  "When tab-line tabs are present, `pro-tabs-line-next' must invoke
`tab-line-switch-to-next-tab' (not any tab-bar function)."
  (let ((buf1 (generate-new-buffer " *test-tabs-1*"))
        (buf2 (generate-new-buffer " *test-tabs-2*")))
    (with-temp-buffer
      (let ((tab-line-mode t)
            (tab-line-called nil)
            (tab-bar-called nil))
        (cl-letf (((symbol-function 'tab-line-tabs-window-buffers)
                   (lambda () (list buf1 buf2)))
                  ((symbol-function 'tab-line-switch-to-next-tab)
                   (lambda (&rest _) (interactive) (setq tab-line-called t)))
                  ((symbol-function 'tab-bar-cycle-select-tab)
                   (lambda (&rest _) (interactive) (setq tab-bar-called t))))
          (pro-tabs-line-next)
          (should tab-line-called)
          (should (not tab-bar-called)))))))

(ert-deftest pro-tabs/line-prev-calls-tab-line-when-present ()
  "When tab-line tabs are present, `pro-tabs-line-prev' must invoke
`tab-line-switch-to-prev-tab' (not any tab-bar function)."
  (let ((buf1 (generate-new-buffer " *test-tabs-1*"))
        (buf2 (generate-new-buffer " *test-tabs-2*")))
    (with-temp-buffer
      (let ((tab-line-mode t)
            (tab-line-called nil)
            (tab-bar-called nil))
        (cl-letf (((symbol-function 'tab-line-tabs-window-buffers)
                   (lambda () (list buf1 buf2)))
                  ((symbol-function 'tab-line-switch-to-prev-tab)
                   (lambda (&rest _) (interactive) (setq tab-line-called t)))
                  ((symbol-function 'tab-bar-cycle-select-tab)
                   (lambda (&rest _) (interactive) (setq tab-bar-called t))))
          (pro-tabs-line-prev)
          (should tab-line-called)
          (should (not tab-bar-called)))))))

(ert-deftest pro-tabs/apply-tab-line-keybindings-binds-ctab ()
  "`pro-tabs--apply-tab-line-keybindings' must bind <C-tab> to
`pro-tabs-line-next' and <C-S-tab> to `pro-tabs-line-prev' so that the
tab-bar default cannot win."
  (pro-tabs--apply-tab-line-keybindings)
  (should (eq (lookup-key (current-global-map) (kbd "<C-tab>"))
              #'pro-tabs-line-next))
  (should (eq (lookup-key (current-global-map) (kbd "<C-S-tab>"))
              #'pro-tabs-line-prev)))

(provide 'test-tabs)
