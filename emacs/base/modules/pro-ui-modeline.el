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

(defcustom pro-ui-shaoline-strategy 'auto-timer
  "Стратегия shaoline-mode по умолчанию.
- 'auto-timer — кастомная стратегия: 1 Гц таймер обновляет time/battery,
  но post-command-hook/reassert/advice/always-visible отключены →
  нет мигания на каждое нажатие клавиши, нет конкуренции за echo-area
  с (message ...). Это компромисс между 'yin (замороженные сегменты)
  и 'adaptive/'yang (мигание echo-area при любом (message ...)).
- 'yin — обновления только по явному вызову `shaoline-update'.
- 'adaptive — поведение shaoline по умолчанию (может мигать)."
  :type '(choice (const auto-timer) (const yin) (const adaptive) (const yang))
  :group 'pro-ui-modeline)

(defun pro-ui--install-shaoline-strategy ()
  "Регистрирует кастомную стратегию 'auto-timer' и применяет её.
Делает shaoline полностью молчаливым: только таймер 1 Гц для
time/battery, без post-command-hook, без advice и без echo-area-reassert.
`always-visible = nil' (а не `t', как в более ранней версии) — это
важно: с always-visible=t shaoline каждый раз восстанавливает своё
сообщение в echo-area при первой возможности, что выглядит как
«мигание» при наборе текста (любой чужой (message ...) сразу же
затирается shaoline'ом). С always-visible=nil shaoline пишет в
echo-area только когда контент реально изменился.

Регистрация через публичный API `shaoline-define-strategy'
(вместо прямого cons-а в `shaoline--strategies') — это
устраняет три класса багов:
  * cons поверх лениво-инициализированного alist-а
    (`shaoline--ensure-core-vars') молча перезаписывался;
  * cons в голову менял порядок стратегий, из-за чего
    `shaoline-toggle-strategy' пропускал новую стратегию;
  * опечатка в ключе (`:always-vicible' вместо `:always-visible')
    тихо давала дефолтное значение.

Идемпотентно: `shaoline-define-strategy' сам заменяет существующую
запись, так что повторный вызов после `pro/reload-config' корректно
обновляет конфигурацию (а не пропускает её через `unless assq')."
  (when (fboundp 'shaoline-define-strategy)
    (shaoline-define-strategy
     'auto-timer
     :update-method  'automatic
     :use-hooks      nil
     :use-advice     nil
     :use-timers     t
     :always-visible nil
     :hide-modelines nil))
  (setq shaoline-mode-strategy 'auto-timer))

(defun pro-ui--enable-shaoline-if-available ()
  "Включает shaoline, если выбран стиль 'shaoline' и пакет доступен.
Функция безопасна к вызову в ранней инициализации — использует require с
nil t и with-eval-after-load для отложенной настройки." 
  (when (and (eq pro-ui-modeline-style 'shaoline) (require 'shaoline nil t))
    (with-eval-after-load 'shaoline
      (pro-ui--install-shaoline-strategy)
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
