;;; pro-ui-icons.el --- Icon integration and cache reset helpers -*- lexical-binding: t; -*-

(defgroup pro-ui-icons nil
  "Icon handling for pro UI"
  :group 'pro-ui)

(defun pro-ui-reset-icons-cache ()
  "Reset icon caches for known icon packages if available.
This is intended to be called after theme changes so icon bitmaps
and caches integrate with the new theme." 
  (when (require 'kind-icon nil t)
    (when (fboundp 'kind-icon-reset-cache) (ignore-errors (kind-icon-reset-cache))))
  (when (require 'treemacs-icons-dired nil t)
    (ignore-errors (when (fboundp 'treemacs-icons-dired-mode)
                     ;; toggle to refresh icons
                     (treemacs-icons-dired-mode -1)
                     (treemacs-icons-dired-mode 1)))))

(add-hook 'pro-ui-after-load-theme-hook #'pro-ui-reset-icons-cache)

(provide 'pro-ui-icons)
