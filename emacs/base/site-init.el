;;; site-init.el --- pro Emacs base -*- lexical-binding: t; -*-

(defvar pro-emacs-base-default-modules '(core ui packages package-bootstrap pro-project git nix js ai agent-shell exwm keys))
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

;; Load Nix-provided package facts early if present.
(let ((provided (expand-file-name "provided-packages.el" (expand-file-name ".config/emacs/" (getenv "HOME")))))
  (when (file-exists-p provided)
    (load provided nil t)))

;; If site-init is loaded directly (for testing or containerized runs) try to
;; locate and load the system support modules (pro-compat, pro-packages)
;; from the repository so modules relying on pro--package-provided-p and
;; helpers work even when init.el didn't preload them.
(unless pro-emacs-base-system-modules-dir
  (let ((base (file-name-directory (or load-file-name buffer-file-name))))
    (setq pro-emacs-base-system-modules-dir (expand-file-name "modules" base))))

(let ((compat (expand-file-name "pro-compat.el" pro-emacs-base-system-modules-dir))
      (packages (expand-file-name "pro-packages.el" pro-emacs-base-system-modules-dir)))
  (when (file-readable-p compat)
    (load compat nil t))
  (when (file-readable-p packages)
    (load packages nil t)))

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
