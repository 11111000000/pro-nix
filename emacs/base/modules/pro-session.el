;;; pro-session.el --- Save/restore session state for soft restart -*- lexical-binding: t; -*-
;; Save a minimal session: open files, point positions, and full window-state.

(require 'subr-x)

(defun pro/session-save (&optional file)
  "Save current session to FILE (elisp). Return path.
Default FILE is "~/.emacs.d/.pro-session.el".
Saved data: alist of (FILE . POINT) and window-state (frame-root-window).
"
  (let* ((out (or file (expand-file-name ".pro-session.el" user-emacs-directory)))
         (buffers (delq nil
                        (mapcar (lambda (b)
                                  (when (and (buffer-file-name b) (buffer-live-p b))
                                    (cons (buffer-file-name b) (with-current-buffer b (point)))))
                                (buffer-list))))
         (wstate (ignore-errors (window-state-get (frame-root-window) t))))
    (with-temp-file out
      (prin1 `(setq pro/session-files ,buffers) (current-buffer))
      (princ "\n" (current-buffer))
      (when wstate
        (prin1 `(setq pro/session-window-state ',wstate) (current-buffer))
        (princ "\n" (current-buffer))))
    (message "pro: session saved to %s" out)
    out))

(defun pro/session-restore (&optional file)
  "Restore session saved in FILE (as written by `pro/session-save').
This will visit files and attempt to restore window state. Returns t on success.
"
  (let* ((in (or file (expand-file-name ".pro-session.el" user-emacs-directory)))
         (buf (when (file-readable-p in) (with-temp-buffer (insert-file-contents in) (buffer-string))))
         (files nil) (wstate nil))
    (when (and buf (not (string-empty-p buf)))
      (load-file in) ;; populates pro/session-files and pro/session-window-state
      (when (boundp 'pro/session-files)
        (setq files pro/session-files))
      (when (boundp 'pro/session-window-state)
        (setq wstate pro/session-window-state)))
    ;; open files
    (dolist (fp files)
      (when (and fp (file-readable-p (car fp)))
        (find-file-noselect (car fp))))
    ;; restore window state if present
    (when wstate
      (condition-case err
          (progn
            (delete-other-windows)
            (window-state-put wstate (frame-root-window) 'safe nil)
            (message "pro: window state restored"))
        (error (message "pro: error restoring window state: %S" err))))
    t))

(provide 'pro-session)

;;; pro-session.el ends here
