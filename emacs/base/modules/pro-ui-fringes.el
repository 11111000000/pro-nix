;;; pro-ui-fringes.el --- Визуальные разделители и fringe -*- lexical-binding: t; -*-
;;
;; Назначение: Настройки fringe и window-divider для тонкой визуальной отделки окон.
;; Контракт: функции безопасны к вызову в headless средах (guarded by display-graphic-p).
;; Публичный API: pro-ui-apply-fringes (идемпотентная функция).
;; Last reviewed: 2026-05-03

(defgroup pro-ui-fringes nil
  "Fringe и разделители окон для pro UI"
  :group 'pro-ui)

(defun pro-ui-apply-fringes ()
  "Применить аккуратные параметры fringe и window-divider в GUI.
Идемпотентна и безопасна к повторному вызову." 
  (when (display-graphic-p)
    (when (fboundp 'window-divider-mode)
      (setq window-divider-default-bottom-width 1
            window-divider-default-places 'bottom-only)
      (window-divider-mode 1))
    ;; Размер fringe по умолчанию
    (when (fboundp 'fringe-mode) (fringe-mode '(8 . 8)))))

(provide 'pro-ui-fringes)
