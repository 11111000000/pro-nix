;;; pro-ui-improvements.el --- Небольшие улучшения UI и их включение -*- lexical-binding: t; -*-
;;
;; Назначение: Собирать и применять рекомендуемые настройки пользовательского
;; интерфейса (шрифты, лигатуры, иконки, автодополнение) в контролируемой
;; последовательности. GUI‑функции защищены проверками display-graphic-p.
;; Контракт: pro-ui-apply-all — идемпотентная публичная функция без побочных
;; эффектов за пределами изменения видимости/шрифтовых настроек Emacs.
;; Proof: ./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el
;; Last reviewed: 2026-05-03
;;

;; Модуль зависит от 'pro-ui' — загружаем опционально, чтобы не проваливать
;; инициализацию в headless средах.
(require 'pro-ui nil t)

(defun pro-ui-apply-all ()
  "Применяет рекомендуемые UI-настройки (шрифты, лигатуры, иконки, completion).
Функция безопасна для интерактивного вызова и для привязки в хуки; каждый шаг
проверяет наличие соответствующих публичных функций перед вызовом." 
  (interactive)
  (when (fboundp 'pro-ui-apply-fonts) (pro-ui-apply-fonts))
  (when (fboundp 'pro-ui-apply-ligatures) (pro-ui-apply-ligatures))
  (when (fboundp 'pro-ui-apply-icons) (pro-ui-apply-icons))
  (when (fboundp 'pro-ui-apply-completion) (pro-ui-apply-completion)))

;; Выполняем после старта GUI-фреймов
(when (display-graphic-p)
  (add-hook 'emacs-startup-hook #'pro-ui-apply-all))

(provide 'pro-ui-improvements)

;;; pro-ui-improvements.el ends here
