;;; package-bootstrap.el --- package bootstrap helpers -*- lexical-binding: t; -*-

(require 'package)

(defconst pro-package-bootstrap-targets
  '(gptel agent-shell magit consult vertico orderless marginalia corfu which-key rainbow-delimiters)
  "Packages that should be present in a fresh Emacs user layer.")

(defun pro-package-bootstrap-install-targets ()
  "Install the default package set if it is missing."
  (interactive)
  (package-refresh-contents)
  (dolist (pkg pro-package-bootstrap-targets)
    (let ((pkg-sym (if (symbolp pkg) pkg (intern pkg))))
      (unless (package-installed-p pkg-sym)
        (condition-case err
            (progn
              (package-install pkg-sym)
              (message "[pro-package-bootstrap] installed %S" pkg-sym))
          (error
           (message "[pro-package-bootstrap] failed %S: %s" pkg-sym (error-message-string err))))))))

(provide 'package-bootstrap)
