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
(global-set-key (kbd "<mouse-3>") #'ignore)
(global-set-key (kbd "<down-mouse-3>") #'ignore)
(global-set-key (kbd "C-<down-mouse-1>") #'ignore)
(dotimes (i (length [mode-line header-line tab-line
                          vertical-line right-divider bottom-divider]))
  (let ((area (aref [mode-line header-line tab-line
                    vertical-line right-divider bottom-divider] i)))
    (define-key (current-global-map)
      (vconcat (list area) [mouse-3]) #'ignore)
    (define-key (current-global-map)
      (vconcat (list area) [down-mouse-3]) #'ignore)
    (define-key (current-global-map)
      (vconcat (list area) (kbd "C-<down-mouse-1>")) #'ignore)))
(when (fboundp 'context-menu-mode)
  (context-menu-mode -1))

(provide 'pro-core)

;;; pro-core.el ends here
