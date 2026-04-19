;;; site-init.el --- pro Emacs base -*- lexical-binding: t; -*-

(defvar pro-emacs-base-default-modules '(core ui keys pro-project git nix js ai exwm))
(defvar pro-emacs-base-system-modules-dir nil)
(defvar pro-emacs-base-user-modules-dir (expand-file-name "~/.config/emacs/modules"))
(defvar pro-emacs-base-user-manifest (expand-file-name "~/.config/emacs/modules.el"))
(defvar pro-emacs-base-disable-marker (expand-file-name "~/.config/emacs/.disable-nixos-base"))

(defun pro-emacs-base--module-file (dir name)
  (expand-file-name (format "%s.el" (if (string= name "project") "pro-project" name)) dir))

(defun pro-emacs-base--manifest-modules ()
  (if (file-exists-p pro-emacs-base-user-manifest)
      (progn
        (load-file pro-emacs-base-user-manifest)
        (cond
         ((boundp 'pro-emacs-modules) pro-emacs-modules)
         ((boundp 'my-emacs-modules) my-emacs-modules)
         ((boundp 'pro-emacs-base-modules) pro-emacs-base-modules)
         (t pro-emacs-base-default-modules)))
    pro-emacs-base-default-modules))

(defun pro-emacs-base--resolve-module (name)
  (let ((user-file (pro-emacs-base--module-file pro-emacs-base-user-modules-dir name))
        (system-file (and pro-emacs-base-system-modules-dir
                          (pro-emacs-base--module-file pro-emacs-base-system-modules-dir name))))
    (cond
     ((file-readable-p user-file) user-file)
     ((and pro-emacs-base-system-modules-dir
           (not (file-exists-p pro-emacs-base-disable-marker))
           (file-readable-p system-file)) system-file)
     (t
       (message "[pro-emacs] module lookup failed: %s user=%s system=%s" name user-file system-file)
       nil))))

(defun pro-emacs-base-start ()
  (let ((modules (pro-emacs-base--manifest-modules)))
    (dolist (module modules)
      (let* ((module-name (if (symbolp module) (symbol-name module) module))
             (file (pro-emacs-base--resolve-module module-name)))
        (if file
            (load file nil t)
          (message "[pro-emacs] missing module: %s" module-name))))
    (message "[pro-emacs] loaded modules: %S" modules)))

(provide 'pro-site-init)
