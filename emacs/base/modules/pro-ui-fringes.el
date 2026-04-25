;;; pro-ui-fringes.el --- Fringe and visual separators helpers -*- lexical-binding: t; -*-

(defgroup pro-ui-fringes nil
  "Fringes and window separators for pro UI"
  :group 'pro-ui)

(defun pro-ui-apply-fringes ()
  "Apply subtle fringe and divider settings in GUI." 
  (when (display-graphic-p)
    (when (fboundp 'window-divider-mode)
      (setq window-divider-default-bottom-width 1
            window-divider-default-places 'bottom-only)
      (window-divider-mode 1))
    ;; Default fringe size
    (when (fboundp 'fringe-mode) (fringe-mode '(8 . 8)))))

(provide 'pro-ui-fringes)
