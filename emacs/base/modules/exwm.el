;;; exwm.el --- EXWM session -*- lexical-binding: t; -*-

(when (require 'exwm nil t)
  (setq exwm-workspace-number 4
        exwm-input-global-keys
        `(([?] . exwm-reset)
          ([?] . exwm-input-release-keyboard)
          (,(kbd "s-r") . exwm-reset)
          (,(kbd "s-w") . exwm-workspace-switch)
          (,(kbd "s-&") . async-shell-command)))
  (when (require 'exwm-systemtray nil t)
    (exwm-systemtray-enable))
  (exwm-enable))

(provide 'exwm)
