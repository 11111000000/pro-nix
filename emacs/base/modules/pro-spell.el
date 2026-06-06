;;; pro-spell.el --- проверка орфографии на лету (ru_RU) -*- lexical-binding: t; -*-
;;
;; Назначение: flyspell в text/prog/comint-режимах с русским hunspell-словарём.
;;
;; Контракт:
;; - ispell-program-name указывает на `pro-hunspell` (см. modules/pro-spellcheck.nix).
;; - ispell-dictionary по умолчанию "ru_RU"; дополнительные словари
;;   (например, "en_US") подключаются через DICPATH и могут быть заданы
;;   в `pro-spell-dictionary' или через переменную `ispell-dictionary'.
;; - Включает flyspell-mode для text-режимов (org, markdown, message, …).
;; - Включает flyspell-prog-mode для prog-режимов (комментарии/строки).
;; - Включает flyspell-mode для comint-режимов (agent-shell, eshell, vterm).
;; - Публичные команды: pro-spell-toggle, pro-spell-change-dictionary.
;;
;; Побочные эффекты: включает flyspell-mode глобально через хуки; изменяет
;; ispell-program-name, ispell-dictionary, ispell-local-dictionary-alist.
;; Эти переменные живут в runtime, custom.el не задействуется.
;;
;; Опции окружения (необязательные):
;; - PRO_SPELL_DICTIONARY="ru_RU,en_US"  → задать мульти-словарь.
;; - PRO_SPELL_DISABLE=1                 → отключить авто-включение.
;;
;; Proof: headless ERT (emacs/base/tests/) и ручной smoke на org/markdown буферах.
;; Last reviewed: 2026-06-06

(require 'ispell)
(require 'flyspell)

(defgroup pro-spell nil
  "Проверка орфографии на лету (hunspell + ru_RU)."
  :group 'pro)

(defcustom pro-spell-program-name "pro-hunspell"
  "Бинарь spell-checker, передаваемый в `ispell-program-name'.
По умолчанию `pro-hunspell' — обёртка, поставляемая модулем
modules/pro-spellcheck.nix, которая проксирует DICPATH на ru_RU
и дополнительные словари."
  :type 'string
  :group 'pro-spell)

(defcustom pro-spell-dictionary "ru_RU"
  "Имя словаря, передаваемое в `ispell-dictionary'.
Например, \"ru_RU\" или \"ru_RU,en_US\" для мульти-словаря. Значение
может быть переопределено переменной окружения PRO_SPELL_DICTIONARY
или стандартной `ispell-dictionary'."
  :type 'string
  :group 'pro-spell)

(defcustom pro-spell-auto-enable t
  "Если non-nil, flyspell включается автоматически через хуки.
При nil авто-включение отключено; пользователь может включить
flyspell вручную через M-x flyspell-mode."
  :type 'boolean
  :group 'pro-spell)

(defvar pro-spell--rus-extra-args '("-d" "ru_RU")
  "Аргументы командной строки hunspell для словаря ru_RU.
Используется в `ispell-local-dictionary-alist'.")

(defun pro-spell--default-dictionary ()
  "Вычислить имя словаря с учётом env-переменной PRO_SPELL_DICTIONARY."
  (or (getenv "PRO_SPELL_DICTIONARY")
      pro-spell-dictionary
      "ru_RU"))

(defun pro-spell--maybe-disabled-p ()
  "Вернуть non-nil, если авто-включение отключено через окружение."
  (let ((val (or (getenv "PRO_SPELL_DISABLE") "")))
    (member val '("1" "yes" "true" "on"))))

(defun pro-spell-configure-ispell ()
  "Настроить ispell для работы с pro-hunspell + ru_RU.
Регистрирует ru_RU в `ispell-local-dictionary-alist', чтобы
ispell-flyspell-verdict корректно классифицировал кириллические
слова. Вызывается при загрузке модуля и при pro/reload-config."
  (setq ispell-program-name pro-spell-program-name)
  (setq ispell-dictionary (pro-spell--default-dictionary))
  ;; Регистрация ru_RU. Формат записи для hunspell:
  ;;   (NAME CASE-RELEVANT REGEXP NOT-CASE-RELEVANT-CHARS IGNORE-CHARS
  ;;         MULTI-LINE-P EXTRA-ARGS AFF-FILE DIC-FILE CODING)
  ;; Для hunspell достаточно NAME и EXTRA-ARGS ("-d" "ru_RU"). Остальные
  ;; поля нужны, чтобы ispell-el корректно токенизировал кириллицу.
  (let ((rus-entry '("ru_RU"
                     "[А-Яа-яЁё]"
                     "[^А-Яа-яЁё]"
                     "['’]"
                     nil
                     ("-d" "ru_RU")
                     nil
                     utf-8)))
    (setq ispell-local-dictionary-alist
          (cons rus-entry
                (assq-delete-all "ru_RU" ispell-local-dictionary-alist))))
  ;; Запасной алиас: ru-ru → ru_RU, чтобы пользователи, привыкшие писать
  ;; через дефис, получали ту же запись.
  (let ((rus-lower '("ru-ru"
                     "[А-Яа-яЁё]"
                     "[^А-Яа-яЁё]"
                     "['’]"
                     nil
                     ("-d" "ru_RU")
                     nil
                     utf-8)))
    (setq ispell-local-dictionary-alist
          (cons rus-lower
                (assq-delete-all "ru-ru" ispell-local-dictionary-alist)))))

(defun pro-spell--enable-text ()
  "Включить flyspell-mode для text-буферов (org, markdown, message…)."
  (when (and (derived-mode-p 'text-mode)
             ;; Не включаем flyspell в minibuffer и read-only буферах.
             (not (minibufferp))
             (not buffer-read-only))
    (flyspell-mode 1)))

(defun pro-spell--enable-prog ()
  "Включить flyspell-prog-mode для prog-буферов (комментарии/строки)."
  (when (derived-mode-p 'prog-mode)
    ;; flyspell-prog-mode — обычный `defun` без аргументов, поэтому
    ;; вызываем без `1` (это `define-minor-mode` для flyspell-mode,
    ;; а prog-вариант включает `flyspell-mode' внутри).
    (flyspell-prog-mode)))

(defun pro-spell--enable-comint ()
  "Включить flyspell-mode для comint-производных буферов.
Покрывает agent-shell, eshell, vterm, shell и т.п. — везде, где
пользователь пишет свободный текст в ответ агенту или в командной
строке. Не включаем в term/vterm-char-mode, чтобы не ломать
позиционирование курсора в терминальных escape-последовательностях."
  (when (and (derived-mode-p 'comint-mode)
             (not (derived-mode-p 'term-mode)))
    (flyspell-mode 1)))

(defun pro-spell-toggle ()
  "Переключить flyspell-mode в текущем буфере."
  (interactive)
  (cond
   ((derived-mode-p 'prog-mode)
    (call-interactively #'flyspell-prog-mode))
   (t
    (call-interactively #'flyspell-mode))))

(defun pro-spell-change-dictionary (dict)
  "Сменить словарь flyspell на DICT (например, \"ru_RU,en_US\")."
  (interactive
   (list (let ((cands (append '("ru_RU" "en_US" "ru_RU,en_US")
                              (mapcar #'car ispell-local-dictionary-alist))))
           (completing-read "Словарь: " cands nil t
                            (or (and (boundp 'ispell-dictionary) ispell-dictionary)
                                "ru_RU")))))
  (setq ispell-dictionary dict)
  (when (bound-and-true-p flyspell-mode)
    (flyspell-mode -1)
    (flyspell-mode 1))
  (message "pro-spell: словарь → %s" dict))

;;; Инициализация

;; Конфигурация ispell выполняется при загрузке модуля. Используем
;; `with-eval-after-load' для режимов, чтобы не зависеть от порядка загрузки
;; ispell/flyspell. ispell.el — built-in, инициализируется раньше прочих
;; наших модулей; установка ispell-program-name сразу же подхватывается
;; при первом вызове flyspell/ispell-region.
(pro-spell-configure-ispell)

(when (and pro-spell-auto-enable
           (not (pro-spell--maybe-disabled-p)))
  ;; Text-режимы: org, markdown, message, fundamental-with-text, и т.д.
  (add-hook 'text-mode-hook #'pro-spell--enable-text)
  ;; Prog-режимы: проверяем только комментарии и строки (не идентификаторы).
  (add-hook 'prog-mode-hook #'pro-spell--enable-prog)
  ;; Comint-режимы: agent-shell, eshell, shell, multi-vterm (comint-производный).
  (add-hook 'comint-mode-hook #'pro-spell--enable-comint)
  ;; На случай, если в системе включён global-flyspell-mode.
  (with-eval-after-load 'flyspell
    (setq flyspell-issue-welcome-flag nil)
    (setq flyspell-use-meta-tab nil)
    (setq flyspell-delay 0.3)
    (setq flyspell-abbrev-p t)))

(provide 'pro-spell)

;;; pro-spell.el ends here
