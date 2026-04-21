;;; emacs/pro-manage.el --- Prototype pro-nix Emacs UI -*- lexical-binding: t; -*-
;; Minimal prototype: list systemd services and allow refresh

(require 'tabulated-list)

(defvar pro-manage-buffer-name "*pro-nix*")

(defun pro-manage--fetch-services ()
  "Fetch list of services (synchronously) by calling systemctl. Returns list of (name desc active enabled)."
  (let ((out (shell-command-to-string "systemctl list-units --type=service --no-legend --all --no-pager")))
    (mapcar (lambda (line)
              (let* ((cols (split-string (string-trim line)))
                     (name (nth 0 cols))
                     (load (nth 1 cols))
                     (active (nth 2 cols))
                     (sub (nth 3 cols))
                     (desc (mapconcat 'identity (nthcdr 4 cols) " ")))
                (list name (vector name active desc))))
            (split-string out "\n" t))))

(defun pro-manage--refresh ()
  (let ((inhibit-read-only t))
    (setq tabulated-list-entries (pro-manage--fetch-services))
    (tabulated-list-print t)))

(define-derived-mode pro-manage-mode tabulated-list-mode "pro-manage"
  "Major mode for pro-nix management UI (prototype)."
  (setq tabulated-list-format [("Service" 40 t) ("Active" 12 t) ("Description" 0 t)])
  (setq tabulated-list-padding 2)
  (add-hook 'tabulated-list-revert-hook 'pro-manage--refresh nil t)
  (tabulated-list-init-header))

(defun pro-manage ()
  "Open pro-nix management buffer (prototype)."
  (interactive)
  (let ((buf (get-buffer-create pro-manage-buffer-name)))
    (with-current-buffer buf
      (pro-manage-mode)
      (pro-manage--refresh))
    (pop-to-buffer buf)))

(provide 'pro-manage)
;;; pro-manage.el ends here
