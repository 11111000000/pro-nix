;;; pro-windows-popups.el --- Оконный менеджер и popups -*- lexical-binding: t; -*-

;; Название: emacs/base/modules/pro-windows-popups.el — Windows, Popper, Ace
;; Кратко: настройки управления окнами, всплывающими буферами и быстрым переключением.
;;
;; Цель:
;;   Улучшить управление окнами через Popper для утилитарных буферов,
;;   Ace-window для навигации и Buffer-expose для обзора.
;;
;; Контракт:
;; - Popper управляет vterm (bottom), gptel (top), org-capture (top), shell/compilation (side).
;; - Buffer-expose обеспечивает обзор буферов.
;; - Ace-window обеспечивает быстрый доступ к окнам.

(require 'pro-ui)

(defun pro-windows-popups-setup ()
  "Инициализировать Popper, Ace-window и вспомогательные функции."
  
  ;; 1. Popper: утилитарные окна
  (when (pro-ui--try-require 'popper)
    (setq popper-reference-buffers
          '("\\*vterm\\*"
            "gptel-buffer"
            "org-capture"
            "\\*shell\\*"
            "\\*compilation\\*"
            "\\*Messages\\*"
            "\\*Help\\*"))

    (setq popper-display-function #'display-buffer-in-side-window)
    (setq popper-scope 'buffer-local)
    
    ;; Popper-alist для специфичных placement
    (setq popper-display-control t)
    (setq popper-group-function nil)

    (popper-mode 1)
    (when (pro-ui--try-require 'popper-echo)
      (popper-echo-mode 1)))

  ;; 2. Ace-window
  (when (pro-ui--try-require 'ace-window)
    (setq aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
    (set-face-attribute 'aw-leading-char-face nil :height 3.0 :weight 'bold))

  ;; 3. Buffer-expose
  (when (pro-ui--try-require 'buffer-expose)
    (setq buffer-expose-size 0.8)))

(pro-windows-popups-setup)

(provide 'pro-windows-popups)
