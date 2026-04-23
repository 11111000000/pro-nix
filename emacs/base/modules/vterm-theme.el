;;; vterm-theme.el --- Minimal vterm color tweaks -*- lexical-binding: t; -*-
;; Apply a compact palette for vterm colors to improve contrast in GUI.

;; Provide a safe theme application function that can be called by init.
(defun pro/vterm-apply-theme ()
  "Apply minimal vterm color tweaks (guarded)."
  (when (display-graphic-p)
    (when (require 'vterm nil t)
      (when (boundp 'vterm-color-map)
        (let ((map (copy-tree vterm-color-map)))
          (when (assoc 'vterm-color-black map) (setf (alist-get 'vterm-color-black map) "#111111"))
          (when (assoc 'vterm-color-white map) (setf (alist-get 'vterm-color-white map) "#e0e0e0"))
          (setq vterm-color-map map))))))

(with-eval-after-load 'vterm
  (pro/vterm-apply-theme))

(provide 'vterm-theme)
