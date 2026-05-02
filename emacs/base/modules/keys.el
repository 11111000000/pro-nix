;;; keys.el --- compatibility shim -> pro-keys -*- lexical-binding: t; -*-
;; Название: emacs/base/modules/keys.el — Legacy shim для pro-keys
;; Цель: обеспечить, чтобы старое имя `keys` продолжало работать, перенаправляя
;;   на `pro-keys` при наличии. Это облегчает постепенную миграцию конфигураций.
;; Контракт: пытается загрузить pro-keys безопасно; публичные функции предоставляются pro-keys.
;; Побочные эффекты: регистрация глобальных клавиатурных биндингов через pro-keys.
;; Proof: emacs/base/tests/test-keys.el (при наличии).
;; Last reviewed: 2026-05-02

(require 'pro-keys nil t)
(provide 'keys)

;;; keys.el ends here
