;;; nav.el --- compatibility shim -> pro-nav -*- lexical-binding: t; -*-
;; Название: emacs/base/modules/nav.el — Legacy shim для pro-nav
;; Цель: сохранить совместимость со старым feature `nav` и делегировать реализацию pro-nav.
;; Контракт: безопасный require pro-nav; не ломать загрузку, если pro-nav отсутствует.
;; Побочные эффекты: регистрация команд навигации и возможно глобальных ключей.
;; Proof: headless ERT для pro-nav и тесты в emacs/base/tests.
;; Last reviewed: 2026-05-02

(require 'pro-nav nil t)
(provide 'nav)

;;; nav.el ends here
