;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; pro-compat.el --- small compatibility shims -*- lexical-binding: t; -*-

(require 'subr-x)

(defvar pro-compat--notified (make-hash-table :test 'equal)
  "Hash for features we've notified about this session.")

(defun pro-compat--notify-once (key fmt &rest args)
  "Notify once per session for KEY with FMT and ARGS." 
  (unless (gethash key pro-compat--notified)
    (puthash key t pro-compat--notified)
    (apply #'message (concat "[pro-compat] " fmt) args)))

;; UI zoom functions
(unless (fboundp 'pro-ui-zoom-in)
  (defcustom pro-ui-zoom-step 10 "Zoom step in tenths of a point." :type 'integer)
  (defun pro-ui-zoom-in (&optional steps)
    (interactive "p")
    (let ((s (* (or steps 1) pro-ui-zoom-step)))
      (when (boundp 'pro-ui-font-height)
        (setq pro-ui-font-height (min 400 (+ pro-ui-font-height s)))
        (when (fboundp 'pro-ui-apply-fonts) (pro-ui-apply-fonts)))
      (message "Font height: %s" (if (boundp 'pro-ui-font-height) pro-ui-font-height "<unknown>"))))
  (defun pro-ui-zoom-out (&optional steps)
    (interactive "p")
    (let ((s (* (or steps 1) pro-ui-zoom-step)))
      (when (boundp 'pro-ui-font-height)
        (setq pro-ui-font-height (max 60 (- pro-ui-font-height s)))
        (when (fboundp 'pro-ui-apply-fonts) (pro-ui-apply-fonts)))
      (message "Font height: %s" (if (boundp 'pro-ui-font-height) pro-ui-font-height "<unknown>"))))
  (defun pro-ui-zoom-reset ()
    (interactive)
    (when (boundp 'pro-ui-font-height)
      (setq pro-ui-font-height 130)
      (when (fboundp 'pro-ui-apply-fonts) (pro-ui-apply-fonts)))
    (message "Font reset to %s" (if (boundp 'pro-ui-font-height) pro-ui-font-height "<unknown>"))))

;; Minimal consult fallbacks
(unless (fboundp 'consult-line)
  (defun consult-line (&rest _)
    (interactive)
    (if (and (require 'consult nil t) (fboundp 'consult-line))
        (call-interactively #'consult-line)
      (pro-compat--notify-once "consult" "'consult' missing — falling back to isearch")
      (call-interactively #'isearch-forward))))

(unless (fboundp 'consult-buffer)
  (defun consult-buffer (&rest _)
    (interactive)
    (if (and (require 'consult nil t) (fboundp 'consult-buffer))
        (call-interactively #'consult-buffer)
      (pro-compat--notify-once "consult-buffer" "'consult-buffer' missing — falling back to ibuffer")
      (call-interactively #'ibuffer))))

;; Minimal magit fallbacks
(unless (fboundp 'magit-status)
  (defun magit-status (&rest args)
    (interactive)
    (if (and (require 'magit nil t) (fboundp 'magit-status))
        (apply #'magit-status args)
      (pro-compat--notify-once "magit" "'magit' missing — falling back to vc-dir")
      (call-interactively #'vc-dir))))

(provide 'pro-compat)

;;; pro-compat.el ends here
