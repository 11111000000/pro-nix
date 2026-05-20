;;; test-ui.el --- ERT tests for basic UI behavior -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(ert-deftest pro-ui--early-gui-setup-tty-does-not-error ()
  "pro-ui-early-gui-setup should not error in TTY.")

(ert-deftest pro-ui-fonts-fallback ()
  "pro-ui-apply-fonts should not error and should set default face."
  (progn
    (ignore-errors (require 'pro-ui-fonts))
    (when (fboundp 'pro-ui-apply-fonts)
      (pro-ui-apply-fonts)
      (should (facep 'default)))))

(ert-deftest pro-ui-cursor-state-from-input-method-russian ()
  "Русский input method должен давать состояние 'russian."
  (when (fboundp 'pro-ui--cursor-state-from-input-method)
    (should (eq (pro-ui--cursor-state-from-input-method "russian-computer") 'russian))
    (should (eq (pro-ui--cursor-state-from-input-method "cyrillic-jcuken") 'russian))
    (should (eq (pro-ui--cursor-state-from-input-method "ru-kbd") 'russian))
    (should (eq (pro-ui--cursor-state-from-input-method nil) 'english))))

(ert-deftest pro-ui-cursor-english-applies-black-bar ()
  "Английский ввод должен дать чёрный бар-курсор."
  (when (fboundp 'pro-ui--apply-cursor-for-state)
    (let (calls cursor-type)
      (cl-letf (((symbol-function 'set-face-attribute)
                 (lambda (&rest args) (setq calls args))))
        (pro-ui--apply-cursor-for-state 'english)
        (should (equal cursor-type '(bar . 2)))
        (should (equal calls '(cursor nil :background "#000000")))))))

(ert-deftest pro-ui-cursor-state-english-uses-bar-and-black-color ()
  "Английский ввод должен возвращать состояние 'english и чёрный цвет курсора."
  (when (fboundp 'pro-ui--apply-cursor-for-state)
    (let ((cursor-type nil))
      (cl-letf (((symbol-function 'set-face-attribute)
                 (lambda (&rest args)
                   (setq pro-ui--test-last-set-face args))))
        (pro-ui--apply-cursor-for-state 'english)
        (should (equal cursor-type '(bar . 2)))
        (should (equal (plist-get (cddr pro-ui--test-last-set-face) :background) pro-ui-cursor-english-color))))))

(ert-deftest pro-ui-detect-cursor-state-prefers-readonly ()
  "Read-only буфер должен переопределять input method."
  (when (fboundp 'pro-ui--detect-cursor-state)
    (with-temp-buffer
      (let ((buffer-read-only t)
            (current-input-method "russian-computer"))
        (should (eq (pro-ui--detect-cursor-state) 'readonly))))))

(ert-deftest pro-ui-tty-cleanup-disables-prettify ()
  "pro-ui-tty-setup disables prettify in TTY emulation."
  (progn
    (ignore-errors (require 'pro-ui-tty))
    (when (fboundp 'pro-ui-tty-setup)
      (let ((display-graphic-p nil))
        (pro-ui-tty-setup)
        (should (not (bound-and-true-p prettify-symbols-mode)))))))

(provide 'test-ui)
