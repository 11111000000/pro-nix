;;; pro-ui-completion.el --- Подсказки завершения и иконки -*- lexical-binding: t; -*-
;;
;; Назначение: интеграция подсказок завершения (Corfu, Cape) и иконок (kind-icon).
;; Контракт:
;; - pro-ui-apply-completion: публичная идемпотентная функция, безопасная к повторному вызову.
;; - Побочные эффекты: регистрация хуков, модификация переменных corfu/cape и добавление форматтеров для margin.
;; Proof: headless ERT (emacs/base/tests/*) и ручные smoke tests.
;; Last reviewed: 2026-05-03

(defgroup pro-ui-completion nil
  "Настройки автодополнения (Corfu/Cape) и интеграция иконок для pro-ui"
  :group 'pro-ui)

(defun pro-ui-apply-completion ()
  "Configure Corfu, Cape and kind-icon integrations.
This is safe to call multiple times." 
  (when (display-graphic-p)
    (when (require 'corfu nil t)
      (setq corfu-auto t
            corfu-auto-prefix 2
            corfu-auto-delay 0.12
            corfu-cycle t
            corfu-count 10
            corfu-separator ?\s
            corfu-echo-documentation nil
            corfu-preselect 'prompt
            corfu-min-width 40
            corfu-max-width 120)
      (when (fboundp 'global-corfu-mode) (global-corfu-mode 1))
      (when (fboundp 'corfu-history-mode) (corfu-history-mode 1)))

    (when (require 'cape nil t)
      (dolist (fn '(cape-file cape-keyword cape-dabbrev))
        (unless (member fn completion-at-point-functions)
          (add-to-list 'completion-at-point-functions fn)))
      (defun pro-ui--disable-ispell-capf ()
        (setq-local completion-at-point-functions
                    (remq #'ispell-completion-at-point completion-at-point-functions)))
      (add-hook 'prog-mode-hook #'pro-ui--disable-ispell-capf)
      (add-hook 'text-mode-hook #'pro-ui--disable-ispell-capf))

    ;; Minibuffer policy
    (defun pro-ui--maybe-enable-corfu-in-minibuffer ()
      (unless (or (bound-and-true-p vertico--input) (bound-and-true-p mct--active))
        (setq-local corfu-auto nil)
        (when (fboundp 'corfu-mode) (corfu-mode 1))))
    (add-hook 'minibuffer-setup-hook #'pro-ui--maybe-enable-corfu-in-minibuffer)

    ;; Kind-icon integration if present
    (when (and (require 'kind-icon nil t) (boundp 'corfu-margin-formatters) (fboundp 'kind-icon-margin-formatter))
      (setq kind-icon-default-face 'corfu-default)
      (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))))

(provide 'pro-ui-completion)
