;;; exwm.el --- EXWM session -*- lexical-binding: t; -*-

;; Этот модуль поднимает EXWM и берёт глобальные клавиши из общего слоя ключей.

(with-eval-after-load 'exwm
  (setq exwm-workspace-number 4)
  (when (boundp 'pro-keys-exwm-global-keys)
    (setq exwm-input-global-keys pro-keys-exwm-global-keys))
  (when (featurep 'exwm-systemtray)
    (exwm-systemtray-enable)))

(provide 'pro-exwm)
