;;; pro-ui-improvements.el --- Small UI improvements and wiring -*- lexical-binding: t; -*-
;; Apply UI niceties in a controlled manner. This file is safe to load in headless
;; environments: GUI-only features are guarded by display-graphic-p.

(require 'ui)

(defun pro-ui-apply-all ()
  "Apply recommended UI settings (fonts, ligatures, icons, completion) when appropriate." 
  (interactive)
  (when (fboundp 'pro-ui-apply-fonts) (pro-ui-apply-fonts))
  (when (fboundp 'pro-ui-apply-ligatures) (pro-ui-apply-ligatures))
  (when (fboundp 'pro-ui-apply-icons) (pro-ui-apply-icons))
  (when (fboundp 'pro-ui-apply-completion) (pro-ui-apply-completion)))

;; Run in graphical frames after initialization
(when (display-graphic-p)
  (add-hook 'emacs-startup-hook #'pro-ui-apply-all))

(provide 'pro-ui-improvements)

;;; pro-ui-improvements.el ends here
