;;; site-init.el --- pro Emacs base -*- lexical-binding: t; -*-

(defconst pro-emacs-base-default-modules '(core ui git nix js ai exwm))
(defconst pro-emacs-base-system-modules-dir "/etc/pro/emacs/modules")
(defconst pro-emacs-base-user-modules-dir (expand-file-name "~/.emacs.d/modules"))
(defconst pro-emacs-base-user-manifest (expand-file-name "~/.emacs.d/modules.el"))
(defconst pro-emacs-base-disable-marker (expand-file-name "~/.emacs.d/.disable-nixos-base"))

(defun pro-emacs-base--module-file (dir name)
  (expand-file-name (format "%s.el" name) dir))

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
        (system-file (pro-emacs-base--module-file pro-emacs-base-system-modules-dir name)))
    (cond
     ((file-exists-p user-file) user-file)
     ((and (not (file-exists-p pro-emacs-base-disable-marker))
           (file-exists-p system-file)) system-file)
     (t nil))))

(defun pro-emacs-base-start ()
  (let ((modules (pro-emacs-base--manifest-modules)))
    (dolist (module modules)
      (let ((file (pro-emacs-base--resolve-module (if (symbolp module) (symbol-name module) module))))
        (if file
            (load file nil t)
          (message "[pro-emacs] missing module: %s" module))))
    (message "[pro-emacs] loaded modules: %S" modules)))

(provide 'pro-site-init)
