;;; pro-ui.el --- Внешний вид и визуальные настройки -*- lexical-binding: t; -*-

;; Название: emacs/base/modules/pro-ui.el — UI: шрифты, иконки, темы, completion
;; Кратко: настройки внешнего вида и интеграция визуальных подсистем (fonts, icons, modeline, completion).
;;
;; Цель:
;;   Предоставить безопасные, воспроизводимые и легко настраиваемые дефолты
;;   для визуального слоя Emacs в профиле pro-nix. Модуль не форсирует пакеты;
;;   он пытается подключать доступные реализации по-очереди.
;;
;; Контракт:
;; - Публичные опции: pro-ui-*-defcustoms (font families, enable-icons, modeline style).
;; - Побочные эффекты: изменение лиц (faces), регистрация хуков и keybindings, запуск background helpers.
;; - Идемпотентность: повторный вызов pro-ui-apply-* функций безопасен.
;;
;; Proof: headless ERT и ручные smoke-тесты через ./scripts/emacs-pro-wrapper.sh
;; Last reviewed: 2026-05-23

(require 'subr-x)

;; Улучшение скроллинга
(setq scroll-conservatively 101       ; плавно скроллить, если точка выходит за экран
      scroll-margin 5                 ; оставлять N строк видимыми вокруг курсора
      scroll-step 1
      scroll-preserve-screen-position t
      mouse-wheel-scroll-amount '(1 ((shift) . 1)) ; плавность для мыши
      mouse-wheel-progressive-speed nil)

;; Отключаем лишние UI-элементы
(scroll-bar-mode -1)
(tool-bar-mode -1)
(menu-bar-mode -1)

(defcustom pro-ui-code-font-family "Aporetic Sans Mono"
  "Шрифт для кода."
  :type 'string
  :group 'pro-ui)

(defcustom pro-ui-text-font-family "Aporetic Sans"
  "Шрифт для текста интерфейса."
  :type 'string
  :group 'pro-ui)

(defcustom pro-ui-font-height 130
  "Высота шрифта в десятых долях пункта."
  :type 'integer
  :group 'pro-ui)

(defcustom pro-ui-enable-ligatures t
  "Включать ли лигатуры в коде."
  :type 'boolean
  :group 'pro-ui)

(defcustom pro-ui-enable-icons t
  "Включать ли иконки в UI-слое."
  :type 'boolean
  :group 'pro-ui)

(defcustom pro-ui-modeline-style 'shaoline
  "Modeline style: 'minimal, 'shaoline or 'doom. Defaults to 'shaoline.
Modeline packages are only enabled if available and if this value
is set accordingly."
  :type '(choice (const minimal) (const shaoline) (const doom))
  :group 'pro-ui)

(defun pro-ui--font-available-p (family)
  "Проверить, доступен ли шрифт FAMILY."
  (find-font (font-spec :family family)))

(defun pro-ui--first-available-font (families)
  "Вернуть первый доступный шрифт из списка FAMILIES."
  (catch 'found
    (dolist (family families)
      (when (pro-ui--font-available-p family)
        (throw 'found family)))
    nil))

(defun pro-ui-apply-fonts ()
  "Применить шрифты к графическому фрейму."
  (when (display-graphic-p)
    (let ((code-font (or (pro-ui--first-available-font '("Fira Code" "JetBrains Mono" "Aporetic Sans Mono" "DejaVu Sans Mono"))
                         pro-ui-code-font-family))
          (text-font (or (pro-ui--first-available-font '("Fira Sans" "Inter" "Aporetic Sans" "DejaVu Sans"))
                         pro-ui-text-font-family)))
      (set-face-attribute 'default nil :family code-font :height pro-ui-font-height)
      (set-face-attribute 'fixed-pitch nil :family code-font :height 1.0)
      (set-face-attribute 'variable-pitch nil :family text-font :height 1.0)
      (let ((font-spec `(font . ,(format "%s-%d" code-font (/ pro-ui-font-height 10)))))
        (unless (assq 'font default-frame-alist)
          (push font-spec default-frame-alist))
        (unless (assq 'font initial-frame-alist)
          (push font-spec initial-frame-alist))))))

(defun pro-ui-apply-ligatures ()
  "Включить лигатуры, если они доступны."
  (when (and pro-ui-enable-ligatures (require 'ligature nil t))
    (ligature-set-ligatures 'prog-mode
                            '("www" "|||" "|>" ":=" ":-" ":>" "->" "->>" "-->" "<=" ">=" "==" "===" "!=" "&&" "||" "///" "/*" "*/" "::" "::=" "++" "**" "~~" "%%"))
    (global-ligature-mode t)))

(defun pro-ui--try-require (feature)
  "Безопасно подключить FEATURE."
  (or (and (boundp 'pro-packages-provided-by-nix)
           (memq feature pro-packages-provided-by-nix)
           (require feature nil t))
      (when (and (fboundp 'pro-packages--maybe-install)
                 (pro-packages--maybe-install feature t))
        (require feature nil t))))

(defun pro-ui-apply-icons ()
  "Подключить полезные иконки без обязательной зависимости.

Стратегия: nerd-icons (BMP/PUA глифы из Nerd Font) пробуется первым;
all-the-icons — fallback, если nerd-icons недоступен. Семейства НЕ
смешиваются: `all-the-icons-scale-factor' имеет смысл только когда
выбран all-the-icons."
  (when (and pro-ui-enable-icons (display-graphic-p))
    (cond
     ((pro-ui--try-require 'nerd-icons)
      (when (pro-ui--try-require 'nerd-icons-ibuffer)
        (add-hook 'ibuffer-mode-hook #'nerd-icons-ibuffer-mode)))
     ((pro-ui--try-require 'all-the-icons)
      (setq all-the-icons-scale-factor 1.0)))

    (when (pro-ui--try-require 'kind-icon)
      (when (boundp 'corfu-margin-formatters)
        (unless (member #'kind-icon-margin-formatter corfu-margin-formatters)
          (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))))

    (with-eval-after-load 'consult
      (cond
       ((pro-ui--try-require 'nerd-icons)
        (when (pro-ui--try-require 'nerd-icons-completion)
          (when (fboundp 'nerd-icons-completion-mode)
            (nerd-icons-completion-mode 1))))
       ((pro-ui--try-require 'all-the-icons)
        (when (pro-ui--try-require 'all-the-icons-completion)
          (when (fboundp 'all-the-icons-completion-mode)
            (all-the-icons-completion-mode 1))))))

    (defvar pro--minibuffer-hint-shown nil "Whether the minibuffer hint was shown this session.")
    (defun pro--show-minibuffer-hint-once ()
      "Show a short help line for minibuffer navigation the first time only."
      (unless pro--minibuffer-hint-shown
        (message "TAB/C-i: next • S-TAB: prev • C-n/C-p/C-j/C-k: navigate • C-.: actions • M-.: preview")
        (setq pro--minibuffer-hint-shown t)))
    (add-hook 'minibuffer-setup-hook #'pro--show-minibuffer-hint-once)))

;; Wire ui subsystems implemented in separate files (pro-nix style).
(when (file-readable-p (expand-file-name "ui-fonts.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-fonts.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))
(when (file-readable-p (expand-file-name "ui-completion.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-completion.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))
(when (file-readable-p (expand-file-name "ui-icons.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-icons.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))
(when (file-readable-p (expand-file-name "ui-modeline.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-modeline.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))
(when (file-readable-p (expand-file-name "ui-theme.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-theme.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))
(when (file-readable-p (expand-file-name "ui-fringes.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-fringes.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))
(when (file-readable-p (expand-file-name "ui-tty.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-tty.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))

(when (fboundp 'add-hook)
  ;; Embark: enable if available to provide quick-actions for candidates
  (when (pro-ui--try-require 'embark)
    (with-eval-after-load 'embark
      (let ((map (make-sparse-keymap)))
        (define-key map (kbd "o") #'embark-act)
        (define-key map (kbd "d") #'embark-dwim)
        (define-key map (kbd "y") #'embark-copy)
        (define-key map (kbd "g") #'embark-collect)
        (when (pro-ui--try-require 'which-key)
          (with-eval-after-load 'which-key
            (which-key-add-key-based-replacements "C-." "Embark actions")))))
    (when (pro-ui--try-require 'embark-consult)
      (with-eval-after-load 'embark-consult
        (when (fboundp 'embark-consult-export)
          (ignore-errors (embark-consult-export)))))

    (when (pro-ui--try-require 'embark)
      (define-key minibuffer-local-map (kbd "C-.") #'embark-act)
      (define-key minibuffer-local-completion-map (kbd "C-.") #'embark-act)
      (when (pro-ui--try-require 'which-key)
        (with-eval-after-load 'pro-keys
          (condition-case _err
              (when (fboundp 'pro/register-module-keys)
                (pro/register-module-keys 'embark
                                          '(("C-." . embark-act))))
            (error (message "pro-ui: failed to register embark suggestion")))))))

;; Embark-Consult: configure default actions and mappings for common types
(when (pro-ui--try-require 'embark-consult)
  (with-eval-after-load 'embark-consult
    (ignore-errors
      (unless (boundp 'embark-consult-sources)
        (defvar embark-consult-sources nil))
      (add-to-list 'embark-consult-sources 'consult--source-project-buffer))))

(defun pro-ui-apply-tabs ()
  "Подключить pro-tabs, если пакет доступен."
  (when (display-graphic-p)
    (when (pro-ui--try-require 'pro-tabs)
      (setq pro-tabs-enable-icons t)
      (when (fboundp 'pro-tabs-mode)
        (pro-tabs-mode 1)))))

(defun pro-ui-apply-completion ()
  "Подключить полезные подсказки для завершения."
  (when (display-graphic-p)
    (when (pro-ui--try-require 'corfu)
      (setq corfu-auto t
            corfu-auto-prefix 3
            corfu-auto-delay 0.25
            corfu-cycle t
            corfu-count 10
            corfu-separator ?\s
            corfu-echo-documentation nil
            corfu-preselect 'prompt
            corfu-min-width 40
            corfu-max-width 120)
      (when (fboundp 'global-corfu-mode) (global-corfu-mode 1))
      (when (fboundp 'corfu-history-mode) (corfu-history-mode 1)))

    (when (pro-ui--try-require 'cape)
      (dolist (fn '(cape-file cape-keyword))
        (unless (member fn completion-at-point-functions)
          (add-to-list 'completion-at-point-functions fn)))
      (defun pro-ui--add-cape-dabbrev ()
        "Add `cape-dabbrev' to `completion-at-point-functions' in prog-mode buffers."
        (unless (member #'cape-dabbrev completion-at-point-functions)
          (add-to-list 'completion-at-point-functions #'cape-dabbrev)))
      (add-hook 'prog-mode-hook #'pro-ui--add-cape-dabbrev)
      (defun pro-ui--disable-ispell-capf ()
        "Remove `ispell-completion-at-point' from `completion-at-point-functions'."
        (setq-local completion-at-point-functions
                    (remq #'ispell-completion-at-point completion-at-point-functions)))
      (add-hook 'prog-mode-hook #'pro-ui--disable-ispell-capf)
      (add-hook 'text-mode-hook #'pro-ui--disable-ispell-capf))

    (defun pro-ui--maybe-enable-corfu-in-minibuffer ()
      "Configure minibuffer completion without enabling Corfu there."
      (unless (or (bound-and-true-p vertico--input) (bound-and-true-p mct--active))
        (setq-local corfu-auto nil)))
    (add-hook 'minibuffer-setup-hook #'pro-ui--maybe-enable-corfu-in-minibuffer)

    (when (and (pro-ui--try-require 'kind-icon)
               (boundp 'corfu-margin-formatters)
               (fboundp 'kind-icon-margin-formatter)
               (not (member #'kind-icon-margin-formatter corfu-margin-formatters)))
      (setq kind-icon-default-face 'corfu-default)
      (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

    (when (fboundp 'set-face-attribute)
      (set-face-attribute 'corfu-default nil :background "#1c1f26" :foreground "#dcdfe4")
      (set-face-attribute 'corfu-current nil :background "#2a2f36" :foreground "#ffffff" :weight 'bold))))

;; Cursor appearance helpers
;; Небольшая утилита: менять цвет и тип курсора в зависимости от
;; текущего метода ввода и режима read-only. Требование: при русском
;; вводе — оранжевый вертикальный бар; при английском — зелёный бар;
;; при read-only — серый полый прямоугольник.
;;
;; Caveat по хукам:
;; - `input-method-activate-hook' срабатывает ПОСЛЕ того, как
;;   `current-input-method' уже выставлен, так что внутри хука видно
;;   актуальное значение.
;; - `input-method-deactivate-hook' срабатывает ДО того, как
;;   `current-input-method' сбрасывается в nil (см. `deactivate-input-method'
;;   в mule-cmds.el: внутренний unwind-protect сначала прогоняет хуки, а
;;   уже затем setq-ит current-input-method в nil). Из-за этого хук
;;   видит старое значение и триггерит «ложный» state, поэтому обновление
;;   откладывается через idle-timer.
;; - В read-only буферах Emacs рисует курсор лицом `cursor-read-only', а
;;   не `cursor'. Нужно обновлять оба лица, иначе наш `:box' игнорируется.
(defcustom pro-ui-cursor-russian-color "#ff8800"
  "Цвет курсора, когда активен русский метод ввода."
  :type 'string
  :group 'pro-ui)

(defcustom pro-ui-cursor-english-color "#00ff00"
  "Цвет курсора для стандартного (английского) ввода.

По умолчанию зелёный — чтобы было заметно при возврате из русского раскладки."
  :type 'string
  :group 'pro-ui)

(defcustom pro-ui-cursor-readonly-color "#808080"
  "Цвет полого прямоугольника в read-only буферах.

Серый по умолчанию — визуально сигнализирует «писать нельзя»."
  :type 'string
  :group 'pro-ui)

(defcustom pro-ui-cursor-readonly-line-width 1
  "Толщина рамки полого прямоугольника в read-only буферах."
  :type 'integer
  :group 'pro-ui)

(defcustom pro-ui-cursor-bar-width 2
  "Ширина вертикального бар-курсора в пикселях (используется как (bar . N))."
  :type 'integer
  :group 'pro-ui)

(defvar-local pro-ui--cursor-last-state nil
  "Последнее применённое состояние курсора для буфера.")

(defun pro-ui--cursor-state-from-input-method (input-method)
  "Вернуть состояние курсора для INPUT-METHOD."
  (if (and input-method
           (string-match-p "russian\\|cyrill?ic\\|ru" input-method))
      'russian
    'english))

(defun pro-ui--detect-cursor-state ()
  "Определить нужное состояние курсора: 'readonly, 'russian или 'english."
  (cond
   (buffer-read-only 'readonly)
   (t (pro-ui--cursor-state-from-input-method
       (and (boundp 'current-input-method) current-input-method)))))

(defun pro-ui--apply-cursor-for-state (state)
  "Применить визуальные настройки курсора для STATE."
  ;; `cursor-read-only' может быть не определён в некоторых контекстах
  ;; (isearch, ранний init), поэтому проверяем `facep' перед записью.
  (pcase state
    ('readonly
     ;; `cursor-type' ставим в обоих режимах (TTY понимает 'box), а
     ;; `:box' на лицах — только в графике: в TTY :box игнорируется,
     ;; и без варнинга оборачивать всё в `display-graphic-p' удобнее
     ;; для headless-тестов.
     (setq cursor-type 'box)
     (when (display-graphic-p)
       (let ((box `(:line-width ,pro-ui-cursor-readonly-line-width
                    :color ,pro-ui-cursor-readonly-color)))
         ;; Полый прямоугольник: :background nil, и только рамка через
         ;; :box. В read-only буфере Emacs использует лицо
         ;; `cursor-read-only', поэтому обновляем и его.
         (set-face-attribute 'cursor nil :background nil :box box)
         (when (facep 'cursor-read-only)
           (set-face-attribute 'cursor-read-only nil :background nil :box box)))))
    ('russian
     (setq cursor-type `(bar . ,pro-ui-cursor-bar-width))
     (when (display-graphic-p)
       (set-face-attribute 'cursor nil
                           :background pro-ui-cursor-russian-color
                           :box nil)
       (when (facep 'cursor-read-only)
         (set-face-attribute 'cursor-read-only nil
                             :background pro-ui-cursor-russian-color
                             :box nil))))
    ('english
     (setq cursor-type `(bar . ,pro-ui-cursor-bar-width))
     (when (display-graphic-p)
       (set-face-attribute 'cursor nil
                           :background pro-ui-cursor-english-color
                           :box nil)
       (when (facep 'cursor-read-only)
         (set-face-attribute 'cursor-read-only nil
                             :background pro-ui-cursor-english-color
                             :box nil)))))))

(defun pro-ui--maybe-update-cursor (&rest _args)
  "Обновить курсор в текущем буфере, если состояние изменилось."
  (let ((new-state (pro-ui--detect-cursor-state)))
    (when (not (eq new-state pro-ui--cursor-last-state))
      (setq pro-ui--cursor-last-state new-state)
      (pro-ui--apply-cursor-for-state new-state))))

(defun pro-ui--force-update-cursor ()
  "Сбросить кеш состояния и применить курсор для текущего буфера.
Оборачиваем в `condition-case': таймер не должен ронять Emacs,
если face временно недоступен (isearch, ранний init)."
  (condition-case nil
      (progn
        (setq pro-ui--cursor-last-state nil)
        (pro-ui--maybe-update-cursor))
    (error nil)))

(defvar pro-ui--cursor-prev-buffer nil
  "Буфер, в котором курсор обновлялся в последний раз.
Используется хуком `pro-ui--cursor-on-buffer-change' для детекта
смены буфера между командами. Глобальная (не per-buffer), потому что
нам нужно сравнивать current-buffer между вызовами.")

(defun pro-ui--cursor-on-buffer-change ()
  "Применить курсор сразу, если current-buffer сменился.
Срабатывает на `post-command-hook' и `after-change-major-mode-hook'.
Гарантирует корректный цвет/форму курсора при открытии файла
(find-file ставит major-mode через `after-change-major-mode-hook') —
раньше это требовало двух нажатий, потому что
`window-buffer-change-functions' срабатывал до того, как
`pro-ui--cursor-last-state' сбрасывался."
  (let ((cur (current-buffer)))
    (unless (eq cur pro-ui--cursor-prev-buffer)
      (setq pro-ui--cursor-prev-buffer cur)
      ;; В новом буфере `pro-ui--cursor-last-state' уже nil (defvar-local),
      ;; но `maybe-update-cursor' всё равно сравнит и применит.
      (condition-case nil
          (pro-ui--maybe-update-cursor)
        (error nil)))))

(defun pro-ui--on-input-method-deactivate ()
  "Хук для input-method-deactivate-hook: отложенное обновление.
  `input-method-deactivate-hook' срабатывает ДО того, как
  `current-input-method' сбрасывается в nil, поэтому немедленный
  re-check увидит прежнее значение. Откладываем на ближайший idle-тик."
  (run-with-idle-timer 0 nil #'pro-ui--force-update-cursor))

(defun pro-ui-apply-cursor-chg ()
  "Инициализировать динамический курсор.
Идемпотентно: повторный вызов (например, после soft reload через
`pro/reload-config', который перечитывает файл) не дублирует хуки.
Все `add-hook' обёрнуты в `unless (memq ...)'."
  (unless (memq #'pro-ui--force-update-cursor input-method-activate-hook)
    (add-hook 'input-method-activate-hook #'pro-ui--force-update-cursor))
  (unless (memq #'pro-ui--on-input-method-deactivate input-method-deactivate-hook)
    (add-hook 'input-method-deactivate-hook #'pro-ui--on-input-method-deactivate))
  (unless (memq #'pro-ui--force-update-cursor read-only-mode-hook)
    (add-hook 'read-only-mode-hook #'pro-ui--force-update-cursor))
  ;; `post-command-hook' + `after-change-major-mode-hook' — главный
  ;; путь обновления при открытии буфера: `find-file' ставит major-mode
  ;; через after-change-major-mode-hook, и наш хук сразу применяет курсор.
  ;; `post-command-hook' страхует для C-x b, мыши и других способов
  ;; смены буфера. Оба хука дешёвые: один eq-сравнение + редкое обновление.
  (unless (memq #'pro-ui--cursor-on-buffer-change post-command-hook)
    (add-hook 'post-command-hook #'pro-ui--cursor-on-buffer-change))
  (unless (memq #'pro-ui--cursor-on-buffer-change after-change-major-mode-hook)
    (add-hook 'after-change-major-mode-hook #'pro-ui--cursor-on-buffer-change))
  (when (fboundp 'window-buffer-change-functions)
    (unless (memq #'pro-ui--force-update-cursor (symbol-value 'window-buffer-change-functions))
      (add-hook 'window-buffer-change-functions
                (lambda (&optional _frame) (pro-ui--force-update-cursor)))))
  (pro-ui--force-update-cursor))

(when (fboundp 'add-hook)
  (when (and (boundp 'vertico-map) (keymapp vertico-map))
    (define-key vertico-map (kbd "C-n") #'vertico-next)
    (define-key vertico-map (kbd "C-p") #'vertico-previous)
    ;; M-n / M-p intentionally left to fall through to
    ;; `next-history-element' / `previous-history-element' (the standard
    ;; minibuffer bindings) so users can step through their input history.
    (define-key vertico-map (kbd "M-n") nil)
    (define-key vertico-map (kbd "M-p") nil))

  (when (and (boundp 'corfu-map) (keymapp corfu-map))
    (define-key corfu-map (kbd "C-n") #'corfu-next)
    (define-key corfu-map (kbd "C-p") #'corfu-previous)
    (define-key corfu-map (kbd "M-n") #'corfu-next)
    (define-key corfu-map (kbd "M-p") #'corfu-previous))

  (when (and (boundp 'vertico-count) (numberp vertico-count))
    (setq vertico-count (min vertico-count 10)))

  (unless (display-graphic-p)
    (when (pro-ui--try-require 'corfu-terminal)
      (when (fboundp 'corfu-terminal-mode) (corfu-terminal-mode 1))))

  (when (and (pro-ui--try-require 'kind-icon) (boundp 'corfu-margin-formatters) (fboundp 'kind-icon-margin-formatter))
    (unless (member #'kind-icon-margin-formatter corfu-margin-formatters)
      (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))))

;; Helper: check icon fonts availability and print install guidance
(defun pro-ui-check-icon-fonts ()
  "Check for common icon fonts (Nerd Fonts / all-the-icons) and print guidance.

This function checks for a few popular patched font families used by
`nerd-icons`/`all-the-icons`. If none are found, it prints a short help
message with recommendations (manual and Home-Manager snippets).
"
  (interactive)
  (let ((candidates '("FiraCode Nerd Font" "Hack Nerd Font" "DejaVu Sans Mono Nerd Font" "Nerd Font" "Aller"))
        found)
    (dolist (f candidates)
      (when (pro-ui--font-available-p f)
        (push f found)))
    (if found
        (message "Icon fonts available: %s" (string-join (nreverse found) ", "))
      (message "No Nerd / icon fonts found. See docs/ICON-FONTS.md for installation instructions."))))

(ignore-errors
  ;; Apply modeline style if the pro-ui-modeline module is available.
  ;; We use `require' with nil t to avoid hard failures in minimal/CI runs.
  (when (require 'pro-ui-modeline nil t)
    (when (fboundp 'pro-ui-apply-modeline)
      (pro-ui-apply-modeline))))

(ignore-errors
  ;; Apply default theme (pro-ui-default-theme, defaults to 'tao-yang).
  ;; The theme package is provided via Nix and is on EMACSLOADPATH; loading
  ;; here means the theme is active as soon as pro-ui is initialized.
  (when (require 'pro-ui-theme nil t)
    (when (fboundp 'pro-ui-apply-theme)
      (pro-ui-apply-theme))))

(ignore-errors
  ;; Wire up dynamic cursor color (russian -> orange, english -> black,
  ;; read-only -> black box). Implemented in pure Elisp; no `cursor-chg'
  ;; package required.
  (when (fboundp 'pro-ui-apply-cursor-chg)
    (pro-ui-apply-cursor-chg)))

(provide 'pro-ui)

;;; pro-ui.el ends here
