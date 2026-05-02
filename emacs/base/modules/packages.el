;;; packages.el --- compatibility shim -> pro-packages -*- lexical-binding: t; -*-
;; Название: emacs/base/modules/packages.el — Legacy shim для pro-packages
;; Цель: обеспечить плавную миграцию старого API `packages` на `pro-packages`.
;; Контракт: безопасный require `pro-packages`; экспорт legacy feature `packages`.
;; Побочные эффекты: регистрация package-инициализации через pro-packages при наличии.
;; Proof: ERT тесты, проверяющие список предоставляемых пакетов (emacs/base/tests).
;; Last reviewed: 2026-05-02

(require 'pro-packages nil t)
(provide 'packages)

;;; packages.el ends here
