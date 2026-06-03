;;; pro-app-launcher.el --- Consult-based Xorg app launcher (EXWM) -*- lexical-binding: t; -*-
;; Контракт:
;;   Публичные команды: pro/app-launcher.
;;   Зависимости: consult (counsel-linux-app — часть пакета consult).
;;   Поведение: после запуска приложения возвращает фокус EXWM-фрейму, чтобы
;;     новое X-окно гарантированно получило фокус и поднялось над Emacs.
;;
;; Last reviewed: 2026-06-04

(require 'consult)

(defun pro/app-launcher ()
  "Consult-style запуск Xorg-приложений по .desktop-файлам.
EXWM-френдли: после выбора приложения фокус возвращается текущему фрейму."
  (interactive)
  (unless (fboundp 'counsel-linux-app)
    (user-error "counsel-linux-app недоступен — пакет consult не загружен"))
  (counsel-linux-app)
  (when (fboundp 'x-focus-frame)
    (run-with-timer 0.15 nil
                    (lambda ()
                      (ignore-errors (x-focus-frame (selected-frame)))))))

(provide 'pro-app-launcher)
