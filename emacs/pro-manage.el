;; Minimal Emacs frontend skeleton for pro-nix management
;; Place in emacs local load-path or load from init

(defvar pro-manage-buffer-name "*pro-manage*")

(defun pro-manage--list-services ()
  "Call proctl list-services (stub) and return an alist of (name . status)."
  ;; For prototype, read systemctl --type=service --no-legend
  (let ((out (shell-command-to-string "systemctl --no-legend --type=service --state=running --all --no-pager | awk '{print $1" "$3}'")))
    (mapcar (lambda (line)
              (let ((parts (split-string (string-trim line))))
                (cons (car parts) (mapconcat 'identity (cdr parts) " "))))
            (split-string out "\n" t))))

(defun pro-manage ()
  "Open pro-manage buffer.")

(defun pro-manage--render ()
  (let ((buf (get-buffer-create pro-manage-buffer-name)))
    (with-current-buffer buf
      (read-only-mode -1)
      (erase-buffer)
      (insert (format "Pro-nix Management\n\n"))
      (insert (format "Services:\n"))
      (dolist (s (pro-manage--list-services))
        (insert (format "- %s: %s\n" (car s) (cdr s))))
      (read-only-mode 1)))
  (switch-to-buffer pro-manage-buffer-name))

(defun pro-manage ()
  (interactive)
  (pro-manage--render))

(provide 'pro-manage)
