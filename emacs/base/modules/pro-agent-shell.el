;;; pro-agent-shell.el --- Adapter for agent-shell package -*- lexical-binding: t; -*-
;; Название: emacs/base/modules/pro-agent-shell.el — Подключатель agent-shell
;; Цель: безопасно подключать пакет `agent-shell` и дать стабильную точку входа
;; `pro-agent-open` для глобальной клавиши `C-c A`.
;; Контракт: отсутствие agent-shell не ломает старт Emacs; команда сообщает,
;; что пакет недоступен, вместо сигнала ошибки.

(defun pro-agent-open ()
  "Открыть agent-shell, если пакет доступен в runtime.

Порядок:
1) попытаться загрузить `agent-shell` через require;
2) если доступна интерактивная команда `agent-shell`, вызвать её;
3) иначе показать диагностическое сообщение без аварии.
"
  (interactive)
  (if (or (featurep 'agent-shell)
          (require 'agent-shell nil t))
      (if (fboundp 'agent-shell)
          (call-interactively #'agent-shell)
        (message "[pro-agent-shell] пакет agent-shell загружен, но команда agent-shell недоступна"))
    (message "[pro-agent-shell] пакет agent-shell не найден (MELPA/Nix). Проверьте package archives и load-path")))

(ignore-errors
  ;; Подгружаем пакет без жёсткой зависимости, чтобы модуль оставался безопасным
  ;; в минимальных окружениях и CI.
  (require 'agent-shell nil t))

(provide 'pro-agent-shell)

;;; pro-agent-shell.el ends here
