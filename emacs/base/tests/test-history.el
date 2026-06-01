;;; test-history.el --- Tests for pro-history layout and policies -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'pro-history)

(ert-deftest pro-history/directories-exist ()
  "pro-history creates expected directories." 
  (should (file-directory-p pro-history-state-directory))
  (should (file-directory-p pro-history-cache-directory))
  (should (file-directory-p pro-history-backup-directory))
  (should (file-directory-p pro-history-auto-save-directory))
  (should (file-directory-p pro-history-auto-save-list-directory))
  (should (file-directory-p pro-history-session-directory))
  (should (file-directory-p pro-history-snapshot-directory)))

(ert-deftest pro-history/paths-not-in-load-path ()
  "State/cache dirs must not be in `load-path'." 
  (should-not (member pro-history-state-directory load-path))
  (should-not (member pro-history-cache-directory load-path)))

(ert-deftest pro-history/backup-configured ()
  "backup-directory-alist points to pro-history backup dir." 
  (let ((entry (assoc ".*" backup-directory-alist)))
    (should entry)
    (should (string-prefix-p (file-name-as-directory pro-history-backup-directory) (cdr entry)))))

(ert-deftest pro-history/auto-save-configured ()
  "auto-save-file-name-transforms uses pro-history auto-save dir." 
  (let ((tf auto-save-file-name-transforms))
    (should (and tf (cl-some (lambda (r) (string-match-p (regexp-quote pro-history-auto-save-directory) (cadr r))) tf)))))

(ert-deftest pro-history/savehist-file ()
  "savehist-file is placed in state dir." 
  (should (string-prefix-p (file-name-as-directory pro-history-state-directory) savehist-file)))

(ert-deftest pro-history/recentf-file ()
  "recentf-save-file is placed in state dir." 
  (should (string-prefix-p (file-name-as-directory pro-history-state-directory) recentf-save-file)))

(ert-deftest pro-history/snapshot-directory-in-paths ()
  "pro-history-describe-paths includes snapshots key."
  (let ((paths (pro-history-describe-paths)))
    (should (assq 'snapshots paths))
    (should (string-suffix-p "snapshots/" (file-name-as-directory (cdr (assq 'snapshots paths)))))))

(ert-deftest pro-history/clear-current-undo-safe ()
  "pro-history-clear-current-undo runs without error even without undo-tree."
  (should (condition-case nil
              (progn (pro-history-clear-current-undo) t)
            (error nil))))

(ert-deftest pro-history/kill-ring-snapshot-roundtrip ()
  "kill-ring snapshot is written and restored as a plain list."
  (let* ((tmp (make-temp-file "pro-history-kill-ring-" nil ".el"))
         (kill-ring '("alpha" "beta" "gamma")))
    (unwind-protect
        (progn
          (should (string-suffix-p ".el" (pro-history-save-kill-ring-snapshot tmp)))
          (setq kill-ring nil)
          (should (pro-history-load-kill-ring-snapshot tmp))
          (should (equal kill-ring '("alpha" "beta" "gamma"))))
      (ignore-errors (delete-file tmp)))))

(ert-deftest pro-history/kill-ring-snapshot-file-content ()
  "pro-history--kill-ring-file-content returns a readable list."
  (let ((result (pro-history--kill-ring-file-content '("one" "two"))))
    (should (stringp result))
    (should (equal (car (read-from-string result)) '("one" "two")))))

(provide 'test-history)

;;; test-history.el ends here

;; Local Variables:
;; no-byte-compile: t
;; End:
