;;; pro-help.el --- Справка и помощь -*- lexical-binding: t; -*-

;; Название: emacs/base/modules/pro-help.el — Справка, подсказки (which-key, eldoc)
;; Кратко: настройки Helpful, elisp-demos, which-key, eldoc-box, keyfreq.
;;
;; Цель:
;;   Улучшить UI помощи с помощью современных инструментов.
;;
;; Контракт:
;; - GUI-специфичные: which-key-posframe, eldoc-box.
;; - Общие: Helpful и Keyfreq.

(require 'pro-ui)

(defun pro-help-setup ()
  "Инициализировать систему помощи (Helpful, which-key, etc)."
  
  ;; Helpful + elisp-demos
  (when (pro-ui--try-require 'helpful)
    (global-set-key [remap describe-function] #'helpful-callable)
    (global-set-key [remap describe-command] #'helpful-command)
    (global-set-key [remap describe-variable] #'helpful-variable)
    (global-set-key [remap describe-key] #'helpful-key)
    
    (when (pro-ui--try-require 'elisp-demos)
      (advice-add 'helpful-update :after #'elisp-demos-advice-helpful-update)))

  ;; Which-key (idle 3s)
  (when (pro-ui--try-require 'which-key)
    (setq which-key-idle-delay 3.0)
    (which-key-mode 1)
    
    (when (and (display-graphic-p) (pro-ui--try-require 'which-key-posframe))
      (which-key-posframe-mode 1)))

  ;; Eldoc-box (GUI только)
  (when (and (display-graphic-p) (pro-ui--try-require 'eldoc-box))
    (add-hook 'eldoc-mode-hook #'eldoc-box-hover-mode))

  ;; Keyfreq
  (when (pro-ui--try-require 'keyfreq)
    (keyfreq-mode 1)
    (keyfreq-autosave-mode 1)))

(pro-help-setup)

(provide 'pro-help)
