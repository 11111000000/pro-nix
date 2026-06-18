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

;; shaoline поставляется через Nix (см. nix/overlays/emacs-extra.nix и
;; modules/pro-users-nixos.nix) и попадает в EMACSLOADPATH так же, как
;; остальные пакеты (pro-tabs, carriage, atlas, ...). Здесь мы поддерживаем
;; только один явный override для разработки: переменная окружения
;; PRO_EMACS_SHAOLINE_PATH, указывающая на каталог с shaoline.el/lisp
;; (например, при запуске Emacs из локального клона submodule вне Nix).
(defvar pro-ui--shaoline-path (getenv "PRO_EMACS_SHAOLINE_PATH")
  "Путь к каталогу с shaoline.el/lisp, заданный через PRO_EMACS_SHAOLINE_PATH.
Пустое значение или несуществующий каталог означают: использовать только
EMACSLOADPATH, который Nix выставляет автоматически.")

(when (and pro-ui--shaoline-path
           (file-directory-p pro-ui--shaoline-path)
           (not (member pro-ui--shaoline-path load-path)))
  (push pro-ui--shaoline-path load-path))

(defcustom pro-ui-modeline-style 'shaoline
  "Стиль модельного слоя: 'minimal, 'shaoline или 'doom.
По умолчанию — 'shaoline. Реализация попытается включить соответствующий
пакет, если он доступен; при отсутствии пакета используется минимальная
встроенная презентация модельного слоя.
Это опция конфигурации без побочных эффектов при чтении." 
  :type '(choice (const minimal) (const shaoline) (const doom))
  :group 'pro-ui-modeline)

(defcustom pro-ui-shaoline-strategy 'adaptive
  "Стратегия shaoline-mode.
- 'yin — обновления только по явному вызову `shaoline-update'. Минимум
  активности, mode-line статичен между ручными апдейтами.
- 'yang — полная активность: post-command-hook, advice, таймеры,
  echo-area-reassert. Максимально отзывчиво, но склонно «мигать»
  echo-area при любом (message ...).
- 'adaptive — компромисс: debounce + rate-limit + context-monitoring
  внутри shaoline (см. shaoline-strategy.el). Без внешних таймеров."
  :type '(choice (const yin) (const adaptive) (const yang))
  :group 'pro-ui-modeline)

(defun pro-ui--apply-shaoline-strategy ()
  "Применяет стратегию из `pro-ui-shaoline-strategy' перед активацией mode.
Ставит `shaoline-mode-strategy' ДО `(shaoline-mode 1)' — shaoline-mode.el
читает эту переменную при активации (shaoline-mode.el:143–148) и сразу
зовёт `shaoline--apply-strategy'. Если значение не зарегистрировано в
`shaoline--strategies' (shaoline.el:863 — там только yin/yang/adaptive),
все настройки будут nil → mode включится, но ни один триггер обновления
не сработает, и mode-line зависнет на первом кадре.

Ранние версии пытались регистрировать кастомную стратегию через
`shaoline-define-strategy' — такой функции в shaoline 3.3.4 нет
(см. submodules/shaoline/lisp/shaoline-strategy.el). Стратегия
'auto-timer' молча проваливалась через `fboundp', а затем `setq'
ставил неизвестное имя в `shaoline-mode-strategy' — это и есть
симптом «запускается но не показывается»."
  (setq shaoline-mode-strategy pro-ui-shaoline-strategy))

(defun pro-ui--enable-shaoline-if-available ()
  "Включает shaoline, если выбран стиль 'shaoline' и пакет доступен.
Функция безопасна к вызову в ранней инициализации — использует require с
nil t и with-eval-after-load для отложенной настройки."
  (when (and (eq pro-ui-modeline-style 'shaoline) (require 'shaoline nil t))
    (with-eval-after-load 'shaoline
      (pro-ui--apply-shaoline-strategy)
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
                  '((:eval (format " %s" (or (buffer-name) ""))))))))

(provide 'pro-ui-modeline)
