;;; reload.el --- Soft reload helpers for pro-nix -*- lexical-binding: t; -*-
;; Safe helpers to reload modules and trigger background package updates.

(require 'subr-x)

(defun pro--resolve-module-file (module)
  "Return absolute path to MODULE el file in pro system modules dir.
MODULE may be a symbol or string like "terminals".
Return nil if not found." 
  (let* ((name (if (symbolp module) (symbol-name module) module))
         (dir (and (boundp 'pro-emacs-base-system-modules-dir) pro-emacs-base-system-modules-dir))
         (path (and dir (expand-file-name (format "%s.el" name) dir))))
    (and path (file-readable-p path) path)))

(defun pro/reload-module (module)
  "Reload MODULE (symbol or string) from pro system modules directory.
This attempts to load the module file with `load-file' and reports success or error.
Returns t on success, nil on failure." 
  (interactive (list (intern (completing-read "Module: " (let ((mods (when (boundp 'pro-emacs-base-default-modules) pro-emacs-base-default-modules))) (mapcar (lambda (s) (if (symbolp s) (symbol-name s) s)) mods) nil t)))) )
  (let ((file (pro--resolve-module-file module)))
    (if (not file)
        (progn (message "pro/reload-module: module file not found: %s" module) nil)
      (condition-case err
          (progn (load-file file) (message "reloaded module %s" module) t)
        (error (message "error reloading %s: %S" module err) nil)))))

(defun pro/reload-all-modules ()
  "Reload all modules listed in `pro-emacs-base-default-modules'.
This is a soft reload: it loads each module file in turn. It will not
recreate stateful singletons; modules should implement idempotent loading to
support this workflow." 
  (interactive)
  (when (boundp 'pro-emacs-base-default-modules)
    (dolist (m pro-emacs-base-default-modules)
      (pro/reload-module m))))

(defun pro/update-melpa-in-background ()
  "Trigger a background Emacs batch process to update MELPA packages.
This runs scripts/melpa-update.el in a separate Emacs --batch process so the
interactive Emacs remains responsive. The background process will refresh
archives and install packages listed in `emacs/base/provided-packages.el' or
`package-selected-packages' as available." 
  (interactive)
    (let* ((repo (file-name-directory (or load-file-name buffer-file-name)))
           (script (expand-file-name "scripts/melpa-update.el" (file-name-directory repo)))
           (cmd (list (or (executable-find "emacs") "emacs") "--batch" "-Q" "-l" script)))
      (message "Starting background MELPA update (see *Messages* for progress)")
      (apply #'start-process "pro-melpa-update" "*pro-melpa-update*" cmd)))

(defun pro/nix-generate-and-refresh-paths ()
  "Run scripts/nix-update-emacs-paths.sh and refresh load-path with results.
This calls the generator script which writes emacs/base/nix-emacs-paths.el and
then loads that file and calls pro/nix-load-path-refresh." 
  (interactive)
  (let* ((repo (file-name-directory (or load-file-name buffer-file-name)))
         (script (expand-file-name "scripts/nix-update-emacs-paths.sh" (file-name-directory repo)))
         (paths-el (expand-file-name "emacs/base/nix-emacs-paths.el" (file-name-directory repo))))
    (when (file-executable-p script)
      (call-process script nil nil nil)
      (when (file-readable-p paths-el)
        (load-file paths-el)
        (when (boundp 'pro/nix-site-lisp-paths)
          (setq pro/nix-site-lisp-paths pro/nix-site-lisp-paths)
          (require 'nix-refresh nil t)
          (pro/nix-load-path-refresh pro/nix-site-lisp-paths)
          (message "pro: nix paths generated and applied")))) )

(defun pro/session-save-and-restart-emacs (&optional save-file)
  "Save session to SAVE-FILE and restart Emacs, restoring session afterwards.
This attempts a smooth restart: it saves open files and window-state, then
spawns a new Emacs process which will load the session on start.
" 
  (interactive)
  (let* ((save (or save-file (pro/session-save)))
         (emacs-bin (or (executable-find "emacs") "emacs"))
         (cmd (list emacs-bin "--eval" (format "(progn (load \"%s\") (pro/session-restore))" save))))
    (message "pro: spawning new Emacs to restore session and exiting current Emacs")
    (apply #'start-process "pro-restart" "*pro-restart*" cmd)
    (kill-emacs)))

(provide 'reload)
