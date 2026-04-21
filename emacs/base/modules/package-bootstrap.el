;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; package-bootstrap.el --- package bootstrap helpers -*- lexical-binding: t; -*-

(require 'package)

 (defconst pro-package-bootstrap-targets
  '(gptel agent-shell magit consult vertico orderless marginalia corfu which-key rainbow-delimiters embark embark-consult)
  "Packages that should be present in a fresh Emacs user layer.")

 (defun pro-package-bootstrap-install-targets ()
   "Install the default package set if it is missing.

This runner honors the pro-packages prompt-and-install policy: it will
attempt to install missing packages noninteractively only when
`PRO_PACKAGES_AUTO_INSTALL` environment variable is set to "1". In
interactive sessions it delegates to `pro-packages--maybe-install` to
prompt the user where appropriate.
"
   (interactive)
      (let ((auto (string= (or (getenv "PRO_PACKAGES_AUTO_INSTALL") "0") "1")))
        (unless pro-packages--refreshed
          (condition-case _ (package-refresh-contents) (error nil))
          (setq pro-packages--refreshed t))
     (dolist (pkg pro-package-bootstrap-targets)
       (let ((pkg-sym (if (symbolp pkg) pkg (intern pkg))))
         (cond
          ((package-installed-p pkg-sym)
           (message "[pro-package-bootstrap] already installed %S" pkg-sym))
          ((and (not noninteractive) (fboundp 'pro-packages--maybe-install))
           (pro-packages--maybe-install pkg-sym t))
          (auto
           (condition-case err
               (progn (package-install pkg-sym) (message "[pro-package-bootstrap] installed %S" pkg-sym))
             (error (message "[pro-package-bootstrap] failed %S: %s" pkg-sym (error-message-string err)))))
          (t
           (message "[pro-package-bootstrap] missing %S (skipped)" pkg-sym)))))))

(provide 'package-bootstrap)
