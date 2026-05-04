;;; test-icons.el --- ERT tests for icon fonts availability -*- lexical-binding: t; -*-

(require 'ert)

(load-file (expand-file-name "../../modules/pro-ui.el" (file-name-directory (or load-file-name buffer-file-name))))

(ert-deftest pro-ui-font-check-fira-or-hack ()
  "Ensure at least one recommended patched icon font family is available." 
  (should (or (pro-ui--font-available-p "FiraCode Nerd Font")
              (pro-ui--font-available-p "Hack Nerd Font")
              (pro-ui--font-available-p "DejaVu Sans Mono Nerd Font"))))

(ert-deftest pro-ui-icon-library-returns-string ()
  "If icon libraries are present, they must return a string for a sample file." 
  (let ((have-nerd (pro-ui--try-require 'nerd-icons))
        (have-all (pro-ui--try-require 'all-the-icons)))
    (when have-nerd
      (should (stringp (nerd-icons-icon-for-file "README.md"))))
    (when (and (not have-nerd) have-all)
      (should (stringp (all-the-icons-icon-for-file "README.md"))))))

(provide 'test-icons)

;;; test-icons.el ends here
