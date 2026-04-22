;;; completion-keys.el --- Keybindings for cape/corfu/consult helpers -*- lexical-binding: t; -*-
;; Safe, lazy keybinding file: binds C-c o <letter> to cape backends

(with-eval-after-load 'cape
  ;; Prefer to bind these only when cape is available.
  (when (fboundp 'cape-file)
    (global-set-key (kbd "C-c o f") #'cape-file))
  (when (fboundp 'cape-dabbrev)
    (global-set-key (kbd "C-c o d") #'cape-dabbrev))
  (when (fboundp 'cape-history)
    (global-set-key (kbd "C-c o h") #'cape-history))
  (when (fboundp 'cape-keyword)
    (global-set-key (kbd "C-c o k") #'cape-keyword))
  (when (fboundp 'cape-symbol)
    (global-set-key (kbd "C-c o s") #'cape-symbol))
  (when (fboundp 'cape-abbrev)
    (global-set-key (kbd "C-c o a") #'cape-abbrev))
  (when (fboundp 'cape-file)
    ;; completion-at-point wrapper for CAPE
    (global-set-key (kbd "C-c o .") #'completion-at-point))

;; consult-yasnippet quick access (if present)
(when (require 'consult-yasnippet nil t)
  (when (fboundp 'consult-yasnippet)
    (global-set-key (kbd "C-c y y") #'consult-yasnippet)))

(provide 'completion-keys)

;;; completion-keys.el ends here
