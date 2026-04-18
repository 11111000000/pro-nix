;;; exwm.el --- EXWM session -*- lexical-binding: t; -*-

;; Этот модуль поднимает EXWM и берёт глобальные клавиши из общего слоя ключей.

(when (require 'exwm nil t)
  (setq exwm-workspace-number 4
        exwm-input-global-keys pro-keys-exwm-global-keys)
  (when (require 'exwm-systemtray nil t)
    (exwm-systemtray-enable))
  (exwm-enable))

(provide 'exwm)
