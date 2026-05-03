;;; test-history.el --- Tests for pro-history layout and policies -*- lexical-binding: t; -*-

(require 'ert)
(require 'pro-history)

(ert-deftest pro-history/directories-exist ()
  "pro-history creates expected directories." 
  (should (file-directory-p pro-history-state-directory))
  (should (file-directory-p pro-history-cache-directory))
  (should (file-directory-p pro-history-backup-directory))
  (should (file-directory-p pro-history-auto-save-directory))
  (should (file-directory-p pro-history-auto-save-list-directory))
  (should (file-directory-p pro-history-session-directory)))

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

(provide 'test-history)

;;; test-history.el ends here
