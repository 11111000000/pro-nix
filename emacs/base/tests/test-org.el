;;; test-org.el --- ERT tests for org configuration -*- lexical-binding: t; -*-

(require 'ert)

(ert-deftest pro-org-configures-babel-and-editor-behavior ()
  "Org should enable the expected local workflow defaults."
  (ignore-errors (require 'pro-org))
  (should (eq org-src-window-setup 'current-window))
  (should (eq org-confirm-babel-evaluate nil))
  (should (eq org-support-shift-select nil))
  (should (equal (alist-get 'plantuml org-babel-load-languages) t))
  (should (equal (alist-get 'mermaid org-babel-load-languages) t)))

(provide 'test-org)

;;; test-org.el ends here
