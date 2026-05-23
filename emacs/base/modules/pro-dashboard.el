;;; pro-dashboard.el --- Dashboard интеграция -*- lexical-binding: t; -*-

;; Название: emacs/base/modules/pro-dashboard.el — Dashboard с футером
;; Кратко: настройки стартовой страницы dashboard с кастомным футером.
;;
;; Цель:
;;   Обеспечить приятную стартовую страницу с полезной информацией (время, фазы, погода).

(require 'pro-ui)

(defun pro-dashboard--footer ()
  "Футер для dashboard с датой, временем, праздниками и луной."
  (let* ((now (decode-time))
         (date-str (format-time-string "%d %b %Y, %A"))
         (time-str (format-time-string "%H:%M"))
         ;; Fallback icons if shaoline isn't fully available
         (moon-icon "🌑"))
    (concat "--- " date-str " | " time-str " | " moon-icon " ---")))

(defun pro-dashboard-setup ()
  "Настройка dashboard."
  (when (pro-ui--try-require 'dashboard)
    (setq dashboard-startup-banner 'logo
          dashboard-show-shortcuts t
          dashboard-items '((recents . 5) (projects . 5))
          dashboard-footer-messages '(()))
    
    (setq dashboard-footer-format (pro-dashboard--footer))
    (dashboard-setup-startup-hook)))

(pro-dashboard-setup)

(provide 'pro-dashboard)
