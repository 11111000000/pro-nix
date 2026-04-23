;;; test-terminals.el --- ERT tests for terminals module -*- lexical-binding: t; -*-

(require 'ert)

(ert-deftest pro-terminals-loads-safe ()
  "Loading terminals module should not error even if vterm missing."
  (should (ignore-errors (load-file (expand-file-name "modules/terminals.el" (file-name-directory (or load-file-name buffer-file-name)))))))

(provide 'test-terminals)
