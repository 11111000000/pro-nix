;;; vterm-theme.el --- Minimal vterm color tweaks -*- lexical-binding: t; -*-
;; Apply a compact palette for vterm colors to improve contrast in GUI.

(when (display-graphic-p)
  (when (require 'vterm nil t)
    (when (boundp 'vterm-color-map)
      ;; tweak a few colors to match UI
      (let ((map (copy-tree vterm-color-map)))
        (setf (alist-get 'vterm-color-black map) "#111111")
        (setf (alist-get 'vterm-color-white map) "#e0e0e0")
        (setq vterm-color-map map)))))

(provide 'vterm-theme)
