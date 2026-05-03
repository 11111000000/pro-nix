;;; pro-ui-icons.el --- Интеграция и сброс кэша иконок -*- lexical-binding: t; -*-
;;
;; Назначение: Поддержка интеграции с популярными пакетами иконок и
;;            безопасный сброс их кэшей после смены темы.
;; Контракт: Операции являются вспомогательными и безопасны к вызову в любом
;;           состоянии; функции проверяют наличие пакетов через require nil t.
;; Public API: pro-ui-reset-icons-cache
;; Proof: ./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el
;; Last reviewed: 2026-05-03
;;

(defgroup pro-ui-icons nil
  "Обработка иконок для pro UI")

(defun pro-ui-reset-icons-cache ()
  "Сбросить кэши иконок для известных пакетов, если они доступны.
Это помогает после смены темы, чтобы иконки снова корректно отрисовывались.
Функция устойчиво игнорирует ошибки на уровне конкретных пакетов." 
  (when (require 'kind-icon nil t)
    (when (fboundp 'kind-icon-reset-cache) (ignore-errors (kind-icon-reset-cache))))
  (when (require 'treemacs-icons-dired nil t)
    (ignore-errors (when (fboundp 'treemacs-icons-dired-mode)
                     ;; toggle to refresh icons
                     (treemacs-icons-dired-mode -1)
                     (treemacs-icons-dired-mode 1)))))

(add-hook 'pro-ui-after-load-theme-hook #'pro-ui-reset-icons-cache)

(provide 'pro-ui-icons)
