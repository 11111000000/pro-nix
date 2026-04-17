;;; ui.el --- визуальная среда -*- lexical-binding: t; -*-

;; Этот модуль собирает внешний вид так, чтобы он был тихим, читаемым и полезным.

(when (fboundp 'menu-bar-mode) (menu-bar-mode -1))
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(blink-cursor-mode 0)
(column-number-mode 1)
(global-hl-line-mode 1)

(setq-default cursor-type '(bar . 3)
              x-stretch-cursor t)

(provide 'ui)
