;;; test-org.el --- tests for Org defaults -*- lexical-binding: t; -*-

(require 'ert)
(require 'pro-org)
(require 'org)

(ert-deftest pro-org-defaults-include-diagrams ()
  (should (eq org-src-window-setup 'current-window))
  (should (null org-confirm-babel-evaluate))
  (should (null org-support-shift-select))
  (should (assoc 'plantuml org-babel-load-languages))
  (should (assoc 'mermaid org-babel-load-languages)))

;;; test-org.el ends here
