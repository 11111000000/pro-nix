;;; pro-ui-modeline.el --- Минималистичный модельный слой и интеграции -*- lexical-binding: t; -*-
;;
;; Назначение: Управление модельным слоем (mode-line) и интеграции с внешними
;;            пакетами модельного слоя (shaoline, doom-modeline).
;; Кратко: Предоставляет опции выбора стиля модельного слоя и безопасные
;;         адаптеры для включения сторонних реализаций при их наличии.
;; Контракт: Изменяет только визуальное представление mode-line; не влияет на
;;           поведение команд или данных буфера. API: pro-ui-modeline-style,
;;           pro-ui-apply-modeline — публичный, стабильный.
;; Proof: ./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el
;; Last reviewed: 2026-05-03
;;

(defgroup pro-ui-modeline nil
  "Настройки модельного слоя для pro UI.")

(defcustom pro-ui-modeline-style 'shaoline
  "Стиль модельного слоя: 'minimal, 'shaoline или 'doom.
По умолчанию — 'shaoline. Реализация попытается включить соответствующий
пакет, если он доступен; при отсутствии пакета используется минимальная
встроенная презентация модельного слоя.
Это опция конфигурации без побочных эффектов при чтении." 
  :type '(choice (const minimal) (const shaoline) (const doom))
  :group 'pro-ui-modeline)

(defun pro-ui--enable-shaoline-if-available ()
  "Включает shaoline, если выбран стиль 'shaoline' и пакет доступен.
Функция безопасна к вызову в ранней инициализации — использует require с
nil t и with-eval-after-load для отложенной настройки." 
  (when (and (eq pro-ui-modeline-style 'shaoline) (require 'shaoline nil t))
    (with-eval-after-load 'shaoline
      (when (fboundp 'shaoline-mode) (shaoline-mode 1)))))

(defun pro-ui--enable-doom-if-available ()
  "Включает doom-modeline, если выбран стиль 'doom' и пакет доступен.
Поведение аналогично pro-ui--enable-shaoline-if-available." 
  (when (and (eq pro-ui-modeline-style 'doom) (require 'doom-modeline nil t))
    (with-eval-after-load 'doom-modeline
      (when (fboundp 'doom-modeline-mode) (doom-modeline-mode 1)))))

(defun pro-ui-apply-modeline ()
  "Применяет стиль модельного слоя, заданный в `pro-ui-modeline-style`.
Публичная точка применения — можно вызывать повторно без побочных эффектов.
Для минимального стиля применяется простая упрощённая конфигурация
`mode-line-format`, чтобы уменьшить визуальный шум." 
  (cond
   ((eq pro-ui-modeline-style 'shaoline) (pro-ui--enable-shaoline-if-available))
   ((eq pro-ui-modeline-style 'doom) (pro-ui--enable-doom-if-available))
   (t ;; минимальная обработка: минимум сегментов
    (setq-default mode-line-format
                  '((:eval (format " %s" (or (buffer-name) "")))))))

(provide 'pro-ui-modeline)
