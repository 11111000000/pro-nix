;;; package-bootstrap.el --- compatibility shim -> pro-package-bootstrap -*- lexical-binding: t; -*-
;; Название: emacs/base/modules/package-bootstrap.el — Legacy shim для pro-package-bootstrap
;; Цель: обеспечить совместимость с предыдущим API пакетного bootstrap и делегировать
;;   реальную инициализацию пакетной подсистемы pro-package-bootstrap.
;; Контракт: импортирует pro-package-bootstrap безопасно; при отсутствии — не вызывает ошибку.
;; Побочные эффекты: возможная регистрация hooks и установка package-archives через pro-package-bootstrap.
;; Proof: тесты ERT, связанные с загрузкой пакетов и инициализацией (emacs/base/tests/*).
;; Last reviewed: 2026-05-02

(require 'pro-package-bootstrap nil t)
(provide 'package-bootstrap)

;;; package-bootstrap.el ends here
