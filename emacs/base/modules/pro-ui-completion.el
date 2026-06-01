;;; pro-ui-completion.el --- Подсказки завершения и иконки -*- lexical-binding: t; -*-
;;
;; Назначение: тонкий compatibility-слой для completion UI.
;; Этот модуль больше не дублирует основную инициализацию Corfu/Cape —
;; она живёт в `pro-completion.el`. Здесь остаются только дополнительные
;; UI-специфичные настройки, безопасные для повторного вызова.

(defgroup pro-ui-completion nil
  "Настройки автодополнения (Corfu/Cape) и интеграция иконок для pro-ui"
  :group 'pro-ui)

(defvar pro-ui-completion--installed nil
  "Non-nil when extra UI completion tweaks were applied.")

(defun pro-ui-apply-completion ()
  "Apply extra UI completion tweaks.

Primary Corfu/Cape setup is handled by `pro-completion.el'. This function only
adds optional UI-facing tweaks once per session."
  (when (and (display-graphic-p) (not pro-ui-completion--installed))
    (setq pro-ui-completion--installed t)
    (when (require 'kind-icon nil t)
      (setq kind-icon-default-face 'corfu-default)
      (when (and (boundp 'corfu-margin-formatters)
                 (fboundp 'kind-icon-margin-formatter)
                 (not (member #'kind-icon-margin-formatter corfu-margin-formatters)))
        (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter)))))

(provide 'pro-ui-completion)
