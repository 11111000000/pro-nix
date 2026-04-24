;;; gui-smoke.el --- basic GUI smoke checks for pro-emacs -*- lexical-binding: t; -*-

(let ((display (getenv "DISPLAY")))
  (unless display
    (message "gui-smoke: no DISPLAY set; test requires Xvfb or a display")
    (kill-emacs 1)))

(message "gui-smoke: starting smoke checks")

(when (not (display-graphic-p))
  (message "gui-smoke: Emacs not in graphical mode")
  (kill-emacs 2))

(message "gui-smoke: display-graphic-p OK")

;; child-frame API check
(condition-case err
    (progn
      (when (fboundp 'make-frame)
        (let ((f (make-frame '((visibility . nil)))))
          (delete-frame f)))
      (message "gui-smoke: frame API available"))
  (error (message "gui-smoke: frame API failed: %S" err) (kill-emacs 3)))

;; check fonts via our helper if available
(when (require 'pro-emacs-check-fonts nil t)
  (pro-emacs-check-fonts))

(message "gui-smoke: done")
(kill-emacs 0)
