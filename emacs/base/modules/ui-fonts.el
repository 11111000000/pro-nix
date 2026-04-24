;;; ui-fonts.el --- Fonts, mixed-pitch and prettify helpers -*- lexical-binding: t; -*-

(defgroup pro-ui-fonts nil
  "Font and typography settings for pro UI"
  :group 'pro-ui)

(defcustom pro-ui-enable-mixed-pitch nil
  "Enable mixed-pitch mode in org-mode and help-mode by default.
This is opt-in because some users prefer consistent monospace in all buffers." 
  :type 'boolean
  :group 'pro-ui-fonts)

(defun pro-ui-apply-fonts ()
  "Apply fonts and emoji fontset. This is safe to call multiple times." 
  (when (display-graphic-p)
    (let* ((code-font (or (pro-ui--first-available-font
                           '("Fira Code" "JetBrains Mono" "Aporetic Sans Mono" "DejaVu Sans Mono"))
                          pro-ui-code-font-family))
           (text-font (or (pro-ui--first-available-font
                           '("Fira Sans" "Inter" "Aporetic Sans" "DejaVu Sans"))
                          pro-ui-text-font-family)))
      (set-face-attribute 'default nil :family code-font :height pro-ui-font-height)
      (set-face-attribute 'fixed-pitch nil :family code-font :height 1.0)
      (set-face-attribute 'variable-pitch nil :family text-font :height 1.0)
      (push `(font . ,(format "%s-%d" code-font (/ pro-ui-font-height 10))) default-frame-alist)
      (push `(font . ,(format "%s-%d" code-font (/ pro-ui-font-height 10))) initial-frame-alist)
      ;; Emoji support if available
      (when (and (display-graphic-p) (fboundp 'set-fontset-font))
        (set-fontset-font "fontset-default" 'unicode "Noto Emoji" nil 'prepend))
      ;; Mixed-pitch opt-in
      (when pro-ui-enable-mixed-pitch
        (when (pro-ui--try-require 'mixed-pitch)
          (add-hook 'org-mode-hook #'mixed-pitch-mode)
          (add-hook 'help-mode-hook #'mixed-pitch-mode)))
      ;; Prettify symbols in GUI
      (when (display-graphic-p)
        (global-prettify-symbols-mode +1)
        (setq prettify-symbols-unprettify-at-point t)))))

(provide 'ui-fonts)
