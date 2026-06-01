;;; test-terminals.el --- ERT tests for terminals module -*- lexical-binding: t; -*-

(require 'ert)

(defvar pro-terminals-test--module
  (expand-file-name "modules/pro-terminals.el"
                    (file-name-directory
                     (directory-file-name
                      (file-name-directory
                       (or load-file-name buffer-file-name))))))

(ert-deftest pro-terminals-loads-safe ()
  "Loading terminals module should not error even if vterm missing."
  (should (ignore-errors (load-file pro-terminals-test--module))))

(ert-deftest pro-terminals-binds-toggle-input-method-in-vterm-mode-map ()
  "Hook must bind C-\\ to toggle-input-method in vterm-mode-map,
so the key is intercepted by Emacs before vterm sends it to the pty."
  (ignore-errors (require 'vterm nil t))
  (when (fboundp 'vterm-mode)
    (load-file pro-terminals-test--module)
    ;; Run the hook manually with a buffer in vterm-mode
    (with-temp-buffer
      (delay-mode-hooks (vterm-mode))
      (run-hooks 'vterm-mode-hook)
      (let ((key (lookup-key vterm-mode-map (kbd "C-\\"))))
        (should (eq key #'toggle-input-method))))))

(provide 'test-terminals)
