;;; ui.el --- light UI defaults -*- lexical-binding: t; -*-

(when (fboundp 'menu-bar-mode) (menu-bar-mode -1))
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(blink-cursor-mode 0)
(column-number-mode 1)
(global-hl-line-mode 1)

(provide 'ui)
