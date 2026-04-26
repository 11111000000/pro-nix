;; melpa-update.el --- Batch script to refresh and install/upgrade MELPA packages
(require 'package)
(setq package-archives '("gnu" . "https://elpa.gnu.org/packages/")
      package-archives '("gnu" . "https://elpa.gnu.org/packages/") )
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)
(unless package-archive-contents (package-refresh-contents))

;; Example: install package list from provided-packages.el if present
(let ((prov-file (expand-file-name "emacs/base/provided-packages.el" (expand-file-name ".." (file-name-directory load-file-name)))))
  (when (file-readable-p prov-file)
    (load-file prov-file)
    (when (boundp 'pro-packages-provided-by-nix)
      (dolist (pkg pro-packages-provided-by-nix)
        (ignore-errors (package-install pkg))))))

(message "melpa update done")
(kill-emacs 0)
