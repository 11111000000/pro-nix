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

(provide 'pro-core)

;;; pro-core.el ends here
