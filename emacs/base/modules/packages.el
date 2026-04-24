;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; packages.el --- package archives and VC packages -*- lexical-binding: t; -*-

;; This module makes Emacs 30+ manage Lisp packages from within Emacs.

(require 'package)
(require 'package-vc)

(defcustom pro-packages-archives
  '(("gnu" . "https://elpa.gnu.org/packages/")
    ("nongnu" . "https://elpa.nongnu.org/nongnu/")
    ("melpa" . "https://melpa.org/packages/"))
  "Package archive configuration used by the pro Emacs base."
  :type '(alist :key-type string :value-type string)
  :group 'pro-ui)

(defcustom pro-packages-archive-priorities
  '(("gnu" . 10)
    ("nongnu" . 10)
    ("melpa" . 50))
  "Archive priorities used by the pro Emacs base.

Higher numbers win when the same package exists in several archives."
  :type '(alist :key-type string :value-type integer)
  :group 'pro-ui)

(defun pro-packages-setup ()
  "Initialize package archives and activate installed packages."
  (setq package-archives pro-packages-archives
        package-archive-priorities pro-packages-archive-priorities
        package-install-upgrade-built-in nil)
  (package-initialize)
  ;; Make sure use-package is available (it may be provided by Nix or ELPA)
  (unless (require 'use-package nil t)
    ;; Only refresh archives if we don't already have metadata or a refresh
    ;; has not been performed earlier in this Emacs session. pro-packages.el
    ;; may have already refreshed archives and set `pro-packages--refreshed`.
    (unless (or package-archive-contents
                (and (boundp 'pro-packages--refreshed) pro-packages--refreshed))
      (condition-case _e
          (progn (package-refresh-contents)
                 (when (boundp 'pro-packages--refreshed)
                   (setq pro-packages--refreshed t)))
        (error (message "[pro-packages] failed to refresh package archives during setup"))))
    (package-install 'use-package)
    (require 'use-package))
  (require 'package-vc)
  (message "[pro-packages] archives=%d priority=%S"
           (length package-archives)
           package-archive-priorities))

(defun pro-packages-refresh ()
  "Refresh package archive metadata."
  (interactive)
  (package-refresh-contents)
  (message "[pro-packages] archive contents refreshed"))

(defun pro-packages-install (package)
  "Install PACKAGE from configured archives."
  (interactive
   (progn
     (package-refresh-contents)
     (list (intern (completing-read "Install package: " (mapcar #'car package-archive-contents))))))
  (package-install package)
  (message "[pro-packages] installed %S" package))

(defun pro-packages-install-vc (package)
  "Install PACKAGE from a VC source."
  (interactive
   (progn
     (package-refresh-contents)
     (list (intern (completing-read "Install VC package: " (mapcar #'car package-archive-contents))))))
  (package-vc-install package)
  (message "[pro-packages] vc-installed %S" package))

(defun pro-packages-upgrade-all ()
  "Upgrade archive and VC packages." 
  (interactive)
  (package-upgrade-all)
  (when (fboundp 'package-vc-upgrade-all)
    (package-vc-upgrade-all))
  (message "[pro-packages] upgrade completed"))

(defun pro-packages-upgrade-built-ins ()
  "Allow upgrading built-in packages once, explicitly."
  (interactive)
  (setq package-install-upgrade-built-in t)
  (message "[pro-packages] built-in upgrades enabled for this session"))

(defun pro-packages-menu ()
  "Open the package list."
  (interactive)
  (list-packages))

(pro-packages-setup)

(provide 'packages)
