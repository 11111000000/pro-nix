;;; test-dired.el --- ERT tests for dired module -*- lexical-binding: t; -*-

(require 'ert)

(ert-deftest pro-dired-loads-nonerror ()
  "Module dired.el should load without error."
  (should (ignore-errors (require 'pro-dired))))

(ert-deftest pro-dired-listing-switches-set ()
  "dired-listing-switches should be set to a sensible default when module loaded."
  (require 'pro-dired)
  (should (string-match "--group-directories-first" dired-listing-switches)))

(provide 'test-dired)
