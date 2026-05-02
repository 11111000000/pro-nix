;;; core.el --- compatibility shim -> pro-core -*- lexical-binding: t; -*-
;; Название: emacs/base/modules/core.el — Legacy shim для pro-core
;; Цель: обеспечить backward-совместимость для кода и тестов, которые ожидают
;;   feature `core`. Модуль просто пробует загрузить `pro-core` безопасно.
;; Контракт: не выбрасывать ошибку при отсутствии pro-core (require с nil t);
;;   отказаться от функционала, если pro-core отсутствует.
;; Побочные эффекты: загрузка pro-core может регистрировать глобальные переменные/хуки.
;; Proof: headless ERT тесты зависящие от legacy feature `core`.
;; Last reviewed: 2026-05-02

(require 'pro-core nil t)
(provide 'core)

;;; core.el ends here
