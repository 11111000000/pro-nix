;;; pro-agent-shell.el --- Адаптер для пакета agent-shell -*- lexical-binding: t; -*-
;; Назначение: гарантировать, что `pro-agent-open` доступна и что модуль
;; загружается безопасно в отсутствие самого пакета agent-shell.
;; Правило: файл должен всегда быть синтаксически корректным и не вызывать ошибок
;; при require в минимальном окружении (CI, контейнеры).

;; Реализация минималистична: задаёт точку входа и аккуратно пытается
;; загрузить опциональные функции из agent-shell.

(defun pro-agent-open ()
  "Открыть agent-shell, если он доступен в runtime.

Если пакет доступен и предоставляет интерактивную команду `agent-shell',
вызываем её. В противном случае выводим информативное сообщение.
"
  (interactive)
  (if (or (featurep 'agent-shell) (require 'agent-shell nil t))
      (if (fboundp 'agent-shell)
          (call-interactively #'agent-shell)
        (message "[pro-agent-shell] пакет agent-shell загружен, но команда agent-shell недоступна"))
    (let ((declared (and (boundp 'pro-packages-provided-by-nix)
                         (memq 'agent-shell pro-packages-provided-by-nix))))
      (if declared
          (message "[pro-agent-shell] пакет agent-shell объявлен Nix, но не найден в runtime. Проверьте профиль / home-manager.")
        (message "[pro-agent-shell] пакет agent-shell не найден. Можно временно установить через M-x pro-packages-install RET agent-shell")))))

;; Попытки необязательной интеграции — выполняются в безопасном ignore-errors.
(ignore-errors
  ;; transient не обязателен; пытаемся загрузить без ошибки.
  (require 'transient nil t)
  (require 'agent-shell nil t))

;; Если пакет доступен — зарегистрируем небольшие обёртки и локальные клавиши.
(condition-case err
    (when (require 'agent-shell nil t)
      ;; Минималистичный заголовок вместо баннера
      (setq agent-shell-header-style 'text
            agent-shell-show-welcome-message nil)
      (defun pro-agent-shell--maybe-call (fn &rest args)
        "Вызвать FN если он определён, иначе показать сообщение.
Аргументы передаются в FN напрямую." (apply (if (fboundp fn) fn (lambda (&rest _) (message "[pro-agent-shell] %s недоступна" fn))) args))

      (defun pro-agent-shell--setup-keys ()
        "Установить локальные клавиши в буфере agent-shell, если режим доступен." 
        (when (derived-mode-p 'agent-shell-mode)
          (when (fboundp 'agent-shell-set-session-model)
            (local-set-key (kbd "C-c m") #'agent-shell-set-session-model))
          (when (fboundp 'agent-shell-set-session-mode)
            (local-set-key (kbd "<tab>") #'agent-shell-set-session-mode))))

      (when (boundp 'agent-shell-mode-hook)
        (add-hook 'agent-shell-mode-hook #'pro-agent-shell--setup-keys))
      (when (boundp 'agent-shell-hook)
        (add-hook 'agent-shell-hook #'pro-agent-shell--setup-keys))
      ;; На крайний случай — добавим advice на команду открытия, если она есть.
      (when (fboundp 'agent-shell)
        (advice-add #'agent-shell :after (lambda (&rest _) (pro-agent-shell--setup-keys)))))
  (error (message "[pro-agent-shell] agent-shell integration skipped: %S" err)))

(defun pro-agent-install ()
  "Убедиться, что пакет `agent-shell' доступен.

Если пакет отсутствует в runtime, попытаемся установить его из MELPA
через политику `pro/packages-ensure' с разрешением fallback (allow-melpa).
Команда безопасна для вызова вручную и выводит читаемое сообщение о результате.
"
  (interactive)
  (condition-case err
      (let ((ok (pro/packages-ensure 'agent-shell t)))
        (if ok
            (if (require 'agent-shell nil t)
                (message "[pro-agent-shell] agent-shell доступен")
              (message "[pro-agent-shell] пакет установлен, но не найден в load-path — перезапустите Emacs"))
          (message "[pro-agent-shell] не удалось обеспечить agent-shell (pro/packages-ensure вернул nil)")))
    (error (message "[pro-agent-shell] ошибка при попытке обеспечить agent-shell: %S" err))))

(provide 'pro-agent-shell)

;;; pro-agent-shell.el ends here
