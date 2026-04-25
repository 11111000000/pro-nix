;; ERT tests for keys parsing and pending/apply logic
;; Run in headless test environment

(require 'ert)
(add-to-list 'load-path (expand-file-name "emacs/base/modules" (getenv "PWD")))

;; The repository modules are prefixed with `pro-`; tests should require
;; the canonical pro- feature names.
(require 'pro-keys)

(ert-deftest pro-test-keys-parse-row ()
  "Parse a single org-table line into binding components."
  (let ((line "| NAV | C-c t | toggle-test | note |"))
    (should (string= (nth 0 (pro-keys--parse-org-table-line line)) "NAV"))
    (should (string= (nth 1 (pro-keys--parse-org-table-line line)) "C-c t"))))

(ert-deftest pro-test-keys-pending-apply ()
  "Pending bindings should be applied when command becomes available."
  (let ((pro-keys-pending-bindings nil)
        (pro-keys-exwm-global-keys nil))
    ;; Add a fake pending entry where command is the symbol 'message (exists)
    (push '(:global "C-c m" message) pro-keys-pending-bindings)
    (pro-keys-apply-pending)
    ;; message is fboundp, so pending should be cleared and binding applied
    (should (equal pro-keys-pending-bindings nil))))

(provide 'tests-keys)
