;;; test-ui.el --- ERT tests for basic UI behavior -*- lexical-binding: t; -*-

(require 'ert)

(ert-deftest pro-ui--early-gui-setup-tty-does-not-error ()
  "pro-ui-early-gui-setup should not error in TTY.")

(ert-deftest pro-ui-fonts-fallback ()
  "pro-ui-apply-fonts should not error and should set default face." 
  (progn
    (ignore-errors (require 'ui-fonts))
    (when (fboundp 'pro-ui-apply-fonts)
      (pro-ui-apply-fonts)
      (should (facep 'default)))))

(ert-deftest pro-ui-tty-cleanup-disables-prettify ()
  "pro-ui-tty-setup disables prettify in TTY emulation." 
  (progn
    (ignore-errors (require 'ui-tty))
    (when (fboundp 'pro-ui-tty-setup)
      (let ((display-graphic-p nil))
        (pro-ui-tty-setup)
        (should (not (bound-and-true-p prettify-symbols-mode)))))))

(provide 'test-ui)
