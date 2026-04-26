#!/usr/bin/env emacs --script

;;; Тест загрузки клавиш из org-таблицы

(add-to-list 'load-path (expand-file-name "emacs/base/modules" (getenv "PWD")))

(require 'keys)

(message "=== Тест загрузки клавиш ===")

(message "Проверяем загрузку org-файла...")
(pro-keys-load-org-file "emacs-keys.org")

(message "Проверяем все привязки клавиш:")

(dolist (key '("C-s" "C-x b" "C-c g" "C-c a" "C-x g"))
  (let ((binding (global-key-binding (kbd key))))
    (if binding
        (message "  %s -> %s" key binding)
      (message "  %s -> НЕ ОПРЕДЕЛЕНА" key))))

(message "=== Конец теста ===")