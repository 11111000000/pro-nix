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
  (unless (featurep 'transient)
    (require 'transient nil t))
  (require 'agent-shell nil t))

;; Если пакет присутствует, добавим удобные локальные привязки клавиш
;; в buffers agent-shell. Не делаем этого жёстко — используем обёртки,
;; которые выводят диагностическое сообщение, если целевые команды
;; недоступны.
(condition-case err
    (when (require 'agent-shell nil t)
      (defun pro-agent-shell--call-set-session-model ()
        "Вызвать `agent-shell-set-session-model' если доступна, иначе показать сообщение."
        (interactive)
        (if (fboundp 'agent-shell-set-session-model)
            (call-interactively #'agent-shell-set-session-model)
          (message "[pro-agent-shell] agent-shell-set-session-model недоступна")))

      (defun pro-agent-shell--call-set-session-mode ()
        "Вызвать `agent-shell-set-session-mode' если доступна, иначе показать сообщение."
        (interactive)
        (if (fboundp 'agent-shell-set-session-mode)
            (call-interactively #'agent-shell-set-session-mode)
          (message "[pro-agent-shell] agent-shell-set-session-mode недоступна")))

      (defun pro-agent-shell--setup-keys ()
        "Установить локальные клавиши для agent-shell buffers.

C-c m -> переключить модель сессии (agent-shell-set-session-model)
TAB    -> выбрать агента / режим сессии (agent-shell-set-session-mode)
"
        (when (derived-mode-p 'agent-shell-mode)
          (local-set-key (kbd "C-c m") #'pro-agent-shell--call-set-session-model)
          ;; TAB обычно имеет важную роль; устанавливаем только локально в agent-shell буфере
          (local-set-key (kbd "<tab>") #'pro-agent-shell--call-set-session-mode)))

      ;; Попробуем зарегистрировать хук для agent-shell-mode, если он определён.
      (cond
       ((boundp 'agent-shell-mode-hook)
        (add-hook 'agent-shell-mode-hook #'pro-agent-shell--setup-keys))
       ((boundp 'agent-shell-hook)
        (add-hook 'agent-shell-hook #'pro-agent-shell--setup-keys))
       (t
        ;; В редком случае, если ни один из хуков не существует, переопределим глобально
        ;; при открытии командой agent-shell: поставим after-advice на команду открытия.
        (when (fboundp 'agent-shell)
          (advice-add #'agent-shell :after (lambda (&rest _) (pro-agent-shell--setup-keys)))))))
  (error (message "[pro-agent-shell] agent-shell load failed, skipping agent-shell integration: %S" err)))

(provide 'pro-agent-shell)

;;; pro-agent-shell.el ends here
