;;; text.el --- чтение и редактирование текста -*- lexical-binding: t; -*-

;; Этот модуль собирает тихие, но полезные настройки для чтения и правки текста.

(setq-default sentence-end-double-space nil)
(setq-default truncate-lines nil)
(setq-default fill-column 88)

(when (fboundp 'electric-pair-mode)
  (electric-pair-mode 1))

(when (fboundp 'show-paren-mode)
  (show-paren-mode 1))

(setq show-paren-delay 0)
(setq show-paren-when-point-inside-paren t)

(when (fboundp 'global-prettify-symbols-mode)
  (global-prettify-symbols-mode 1))

(when (or (pro--package-provided-p 'eldoc) (pro-packages--maybe-install 'eldoc t) (require 'eldoc nil t))
  ;; Guard eldoc function presence; some Emacs builds may not provide it.
  (when (boundp 'eldoc-idle-delay)
    (setq eldoc-idle-delay 0.4)))

(provide 'text)
