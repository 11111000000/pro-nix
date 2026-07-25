;;; pro-core.el --- core helpers -*- lexical-binding: t; -*-
;; Название: emacs/base/modules/pro-core.el — Основные утилиты pro-core
;; Цель: собрать базовые функции, используемые другими модулями (регистрация хуков,
;;   обработка ошибок, общие helper'ы).
;; Контракт: публичные функции должны иметь docstring и быть idempotent при повторной инициализации.
;; Побочные эффекты: регистрация глобальных hooks и переменных состояния.
;; Proof: emacs/base/tests/* (см. тесты на core behavior).
;; Last reviewed: 2026-05-02

;; Core defaults expected by tests and by modules: keep minimal and stable.
;; These are global defaults (not buffer-local) that make editor behaviour
;; reproducible in headless/test environments.
;; Ensure both default and current-value are set so headless test buffers
;; that evaluate `indent-tabs-mode' see the expected value.
(setq-default indent-tabs-mode nil)
(setq indent-tabs-mode nil)
(setq-default fill-column 88)
(setq fill-column 88)
(setq ring-bell-function 'ignore)

;; GC tuning: defaults (800k / 0.1) cause Emacs to spend visible time in
;; `Automatic GC' under interactive agent-shell / flyspell load (profile
;; 2026-06 showed ~32%). Raise the threshold so collection runs less often
;; and amortizes better. pro-ui-tty.el may further override for TTY frames.
(defcustom pro-core-gc-cons-threshold (* 128 1024 1024)
  "Steady-state value for `gc-cons-threshold' installed by pro-core.
128 MiB keeps GC pauses rare without making them painfully long; tune
downward on memory-constrained hosts (Raspberry Pi, etc.).
Raised from 64 MiB after the 2026-06 I/O profiling showed GC was
still firing often enough to be visible in `Automatic GC' profile
columns during long opencode / nix flake check sessions."
  :type 'integer
  :group 'pro)

(defcustom pro-core-gc-cons-percentage 0.3
  "Steady-state value for `gc-cons-percentage' installed by pro-core."
  :type 'number
  :group 'pro)

(setq gc-cons-threshold pro-core-gc-cons-threshold
      gc-cons-percentage pro-core-gc-cons-percentage)

;; Safety net: disable right-click context menus that can deadlock X focus.
;; Emacs 30 binds `mouse-buffer-menu' to C-<down-mouse-1> globally, and
;; mode-line / header-line / tab-line have their own per-area bindings.
;; Any of these drops Emacs into `recursive-edit' and traps the keyboard
;; if hit accidentally under X11 + Cinnamon. This block runs at every
;; pro-core load (startup and `pro/reload-config') and is the source of
;; truth; emacs-keys.org is intentionally NOT used because the unbinding
;; must be in effect before the Org table is reparsed.

(defvar pro-core--locked-mouse-menus nil
  "Non-nil once `pro-core--lock-mouse-menus' has run in this session.
Used to avoid noisy repeat logging from the `after-load-functions' hook.")

(defvar pro-core--mouse-menu-areas
  '[mode-line header-line tab-line
              vertical-line right-divider bottom-divider
              window-divider help-line]
  "Area symbols whose keymaps must have mouse-menu events unbound.
Kept in sync with Emacs 30+ defaults; `window-divider' and `help-line'
are added defensively for newer builds where new areas exist but our
code is unaware of them.")

(defvar pro-core--mouse-menu-events
  ;; Soft mode: блокируем ТОЛЬКО правую кнопку (<mouse-3> family) во всех
  ;; area + C-<down-mouse-1> globally. <mouse-1> оставляем — нужен для
  ;; selection и drag (в т.ч. tab-line-select-tab).
  '([mouse-3]
    [down-mouse-3]
    (C-down-mouse-1))
  "Mouse/keyboard events that open X11 menu popups and must be `#'ignore'.

Каждый элемент — либо vector (мышиное событие), либо список модификаторов
для `global-set-key' (через `kbd'). Хранится как data, чтобы логика
была одна и та же в нескольких местах.")

(defun pro-core--lock-mouse-menus ()
  "Глобально отключить события, открывающие X11 popup-меню.

Идемпотентна: повторный вызов просто переприменяет unbinding. Вызывается
из top-level pro-core.el (при старте и `pro/reload-config') и из
`after-load-functions' на случай, если 3rd-party библиотеки
(magit/treemacs/tab-bar) перебиндивают свои keymap'ы уже после загрузки
нашего модуля.

Soft mode: блокируем <mouse-3> и <down-mouse-3> во всех area keymap'ах,
а также C-<down-mouse-1> глобально. <mouse-1> остаётся живым (select/drag
в mode-line и tab-line)."
  (interactive)
  ;; 1. Глобальные привязки.
  (global-set-key (kbd "<mouse-3>") #'ignore)
  (global-set-key (kbd "<down-mouse-3>") #'ignore)
  (global-set-key (kbd "C-<down-mouse-1>") #'ignore)
  ;; 1a. <mouse-3> с модификаторами. M-<mouse-3> и S-<mouse-3> тоже часто
  ;; проксируют в buffer/major-mode menu.
  (dolist (mod '("C-" "M-" "S-" "s-" "C-M-" "C-S-" "M-S-" "C-s-"
                 "C-M-s-" "C-M-S-"))
    (global-set-key (kbd (concat mod "<down-mouse-3>")) #'ignore)
    (global-set-key (kbd (concat mod "<mouse-3>")) #'ignore))
  ;; 1b. double/triple click правой кнопки.
  (dolist (prefix '("double-mouse-" "triple-mouse-"))
    (global-set-key (kbd (concat prefix "3")) #'ignore))
  (dolist (prefix '("double-down-mouse-" "triple-down-mouse-"))
    (global-set-key (kbd (concat prefix "3")) #'ignore))
  ;; 1c. <C-down-mouse-1> с дополнительными модификаторами.
  (dolist (mod '("M-" "S-" "s-" "C-M-" "C-S-" "M-S-"))
    (global-set-key (kbd (concat mod "C-<down-mouse-1>")) #'ignore))

  ;; 2. Per-area привязки. Только правая кнопка (<mouse-3> family) —
  ;; soft mode оставляет <mouse-1> живым для select/drag.
  (dolist (area-symbol (append pro-core--mouse-menu-areas nil))
    (let ((area (or (and (boundp area-symbol) (symbol-value area-symbol))
                    area-symbol)))
      (when (or (symbolp area) (integerp area))
        (let ((map (current-global-map)))
          ;; Правая кнопка без модификаторов.
          (define-key map (vconcat (list area) [mouse-3]) #'ignore)
          (define-key map (vconcat (list area) [down-mouse-3]) #'ignore)
          (define-key map (vconcat (list area) [C-down-mouse-1]) #'ignore)
          ;; Правая кнопка с модификаторами.
          (define-key map (vconcat (list area) [C-mouse-3]) #'ignore)
          (define-key map (vconcat (list area) [C-down-mouse-3]) #'ignore)
          (define-key map (vconcat (list area) [M-mouse-3]) #'ignore)
          (define-key map (vconcat (list area) [M-down-mouse-3]) #'ignore)
          (define-key map (vconcat (list area) [S-mouse-3]) #'ignore)
          (define-key map (vconcat (list area) [S-down-mouse-3]) #'ignore)
          (define-key map (vconcat (list area) [s-mouse-3]) #'ignore)
          (define-key map (vconcat (list area) [s-down-mouse-3]) #'ignore)))))

  ;; 3. Встроенные Emacs 30+ keymap'ы, которые X11 триггерит напрямую.
  ;; Даже если global-map защищён, событие может попасть в эти keymap
  ;; мимо нас.
  (when (boundp 'mouse-buffer-menu-map)
    (when (keymapp mouse-buffer-menu-map)
      (define-key mouse-buffer-menu-map [mouse-1] #'ignore)
      (define-key mouse-buffer-menu-map [mouse-3] #'ignore)
      (define-key mouse-buffer-menu-map [down-mouse-1] #'ignore)
      (define-key mouse-buffer-menu-map [down-mouse-3] #'ignore)))
  (when (boundp 'context-menu-map)
    (setq context-menu-map (make-sparse-keymap)))
  (when (fboundp 'context-menu-mode)
    (context-menu-mode -1))

  ;; 4. Клавиатурные пути в menu-bar.
  (global-set-key (kbd "<f10>") #'ignore)
  (global-set-key (kbd "C-<f10>") #'ignore)
  (global-set-key (kbd "M-<f10>") #'ignore)
  (global-set-key (kbd "s-<f10>") #'ignore)

  (unless pro-core--locked-mouse-menus
    (setq pro-core--locked-mouse-menus t)
    (message "[pro-core] locked X11 mouse-menu events (soft mode)")))

(defun pro-core--diagnose-mouse-menus ()
  "Список mouse/keyboard events, всё ещё привязанных к menu-командам.

Полезно для диагностики: после `pro-core--lock-mouse-menus' список должен
быть пустым или содержать только разрешённые <mouse-1> bindings в area
(которые мы намеренно НЕ трогаем в soft mode)."
  (interactive)
  (let ((hits nil)
        (menu-cmds '(mouse-major-mode-menu mouse-buffer-menu
                                           mouse-menu-bar-map context-menu
                                           menu-bar-open tmm-menubar)))
    ;; Сканируем global-map.
    (map-keymap
     (lambda (k binding)
       (let* ((sym (and (symbolp binding) (symbol-name binding)))
              (vec (and (vectorp binding) (vectorp (aref binding 0))))
              (is-menu (or (and sym (cl-find-if (lambda (m) (string-prefix-p (symbol-name m) sym)) menu-cmds))
                           (and vec (keymapp binding)))))
         (when is-menu
           (push (list :global k binding) hits))))
     (current-global-map))
    ;; Сканируем все area keymap.
    (dolist (area-sym (append pro-core--mouse-menu-areas nil))
      (let* ((area (or (and (boundp area-sym) (symbol-value area-sym))
                       area-sym))
             (map (and (or (symbolp area) (integerp area))
                       (lookup-key (current-global-map)
                                   (vector area)))))
        (when (keymapp map)
          (map-keymap
           (lambda (k binding)
             (let* ((sym (and (symbolp binding) (symbol-name binding)))
                    (is-menu (and sym (cl-find-if (lambda (m) (string-prefix-p (symbol-name m) sym)) menu-cmds))))
               (when is-menu
                 (push (list area k binding) hits))))
           map))))
    (with-output-to-temp-buffer "*pro-core-mouse-diag*"
      (princ (format "Mouse-menu bindings detected: %d\n" (length hits)))
      (princ "---\n")
      (dolist (h hits)
        (princ (format "  %S\n" h)))
      (princ "---\n")
      (princ "Soft mode intentionally allows <mouse-1> in area keymaps.\n"))
    (message "[pro-core] diagnose: %d menu bindings remain (see *pro-core-mouse-diag*)"
             (length hits))))

(pro-core--lock-mouse-menus)

;; Если 3rd-party library (magit transient, treemacs, tab-bar) перебиндивает
;; свой keymap после нашей загрузки — переприменяем unbinding. Хук
;; `after-load-functions' срабатывает после загрузки любого файла.
(add-hook 'after-load-functions
          (lambda (&rest _)
            (ignore-errors (pro-core--lock-mouse-menus))))

;; Дополнительный safety net: после смены window configuration (в EXWM это
;; бывает при переключении workspace) на случай, если X-сервер или WM
;; перебиндивают ключи.
(add-hook 'window-configuration-change-hook
          (lambda ()
            (ignore-errors (pro-core--lock-mouse-menus))))

(provide 'pro-core)

;;; pro-core.el ends here
