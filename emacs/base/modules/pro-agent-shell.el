;;; pro-agent-shell.el --- Adapter for agent-shell package -*- lexical-binding: t; -*-
;; Название: emacs/base/modules/pro-agent-shell.el — Подключатель agent-shell
;; Цель: безопасно подключать пакет `agent-shell` когда он доступен, и
;; предоставить feature `pro-agent-shell` для остальных модулей.
;; Контракт: не вызывать ошибку при отсутствии пакета (require с nil t).
;; Побочные эффекты: при наличии пакета может регистрировать команды/функции;
;; этот файл только делает require и может содержать лёгкие настройки.

(ignore-errors
  ;; Try to load agent-shell if the package is installed on load-path or
  ;; provided by Nix. Do not signal when absent — callers should check
  ;; featurep/require themselves when they need stronger guarantees.
  (require 'agent-shell nil t))

(provide 'pro-agent-shell)

;;; pro-agent-shell.el ends here
