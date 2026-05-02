;;; pro-core.el --- core helpers -*- lexical-binding: t; -*-
;; Название: emacs/base/modules/pro-core.el — Основные утилиты pro-core
;; Цель: собрать базовые функции, используемые другими модулями (регистрация хуков,
;;   обработка ошибок, общие helper'ы).
;; Контракт: публичные функции должны иметь docstring и быть idempotent при повторной инициализации.
;; Побочные эффекты: регистрация глобальных hooks и переменных состояния.
;; Proof: emacs/base/tests/* (см. тесты на core behavior).
;; Last reviewed: 2026-05-02

(provide 'pro-core)

;;; pro-core.el ends here
