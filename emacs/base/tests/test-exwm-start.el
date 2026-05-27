;;; test-exwm-start.el --- Тесты запуска EXWM -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(load-file (expand-file-name "../modules/pro-exwm.el"
                             (file-name-directory (or load-file-name buffer-file-name))))

(ert-deftest pro/exwm-starts-only-in-exwm-session ()
  "EXWM запускается только когда XDG_CURRENT_DESKTOP равен EXWM."
  (let ((started nil)
        (old-exwm (when (featurep 'exwm) t)))
    (cl-letf (((symbol-function 'exwm-wm-mode)
               (lambda (&optional arg)
                 (setq started arg))))
      (unwind-protect
          (progn
            (setenv "XDG_CURRENT_DESKTOP" "EXWM")
            (pro-exwm-start-session)
            (should (equal started 1))
            (setq started nil)
            (setenv "XDG_CURRENT_DESKTOP" "GNOME")
            (pro-exwm-start-session)
            (should (null started)))
        (setenv "XDG_CURRENT_DESKTOP" nil)))))
