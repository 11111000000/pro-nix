;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; package-bootstrap.el --- package bootstrap helpers -*- lexical-binding: t; -*-

(require 'package)

 (defconst pro-package-bootstrap-targets
  '(gptel agent-shell magit consult vertico orderless marginalia corfu which-key rainbow-delimiters embark embark-consult
    nerd-icons nerd-icons-completion nerd-icons-ibuffer all-the-icons all-the-icons-completion all-the-icons-dired consult-projectile which-key pro-fix-corfu)
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
      ;; Default to auto-install enabled when the environment variable is
      ;; not present. This makes fresh profiles bootstrap missing packages
      ;; automatically.
       (let ((auto (string= (or (getenv "PRO_PACKAGES_AUTO_INSTALL") "1") "1"))
             (missing nil))
         ;; Compute which packages are actually missing before refreshing.
         (dolist (pkg pro-package-bootstrap-targets)
           (let ((pkg-sym (if (symbolp pkg) pkg (intern pkg))))
             (unless (or (package-installed-p pkg-sym)
                         (locate-library (symbol-name pkg-sym))
                         (and (boundp 'pro-packages-provided-by-nix)
                              (memq pkg-sym pro-packages-provided-by-nix)))
               (push pkg-sym missing))))

         (when missing
           ;; Refresh archives once per session only when there is work to do.
           (unless pro-packages--refreshed
             (condition-case _ (package-refresh-contents) (error nil))
             (setq pro-packages--refreshed t))

           (dolist (pkg-sym (nreverse missing))
             (if (package-installed-p pkg-sym)
                 (message "[pro-package-bootstrap] already installed %S" pkg-sym)
               (cond
                ((and (not noninteractive) (fboundp 'pro-packages--maybe-install))
                 (pro-packages--maybe-install pkg-sym t))
                (auto
                 (condition-case err
                     (progn (package-install pkg-sym) (message "[pro-package-bootstrap] installed %S" pkg-sym))
                   (error (message "[pro-package-bootstrap] failed %S: %s" pkg-sym (error-message-string err)))))
                (t
                 (message "[pro-package-bootstrap] missing %S (skipped)" pkg-sym))))))))

(provide 'package-bootstrap)

;; Auto-run bootstrap installer when environment requests auto-install.
(when (string= (or (getenv "PRO_PACKAGES_AUTO_INSTALL") "1") "1")
  ;; Run lazily but during init so missing packages are available later.
  (ignore-errors (pro-package-bootstrap-install-targets)))
