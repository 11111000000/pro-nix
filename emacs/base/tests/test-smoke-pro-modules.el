;;; test-smoke-pro-modules.el --- Smoke test: require all pro-* modules -*- lexical-binding: t; -*-
;;
;; Простой ERT-тест, который пытается `require` каждый модуль
;; emacs/base/modules/pro-*.el по имени фичи (provide 'pro-<name>). Это
;; призвано ловить явные ошибки загрузки модулей при рефакторинге и
;; служит базовым контракт-тестом для CI.

(require 'ert)

(ert-deftest pro-smoke/require-all-modules ()
  "Require all emacs/base/modules/pro-*.el modules without error.

Тест делает только неблокирующие require'ы — используем (require F nil t)
чтобы избежать интерактивных промптов и нежелательной установки пакетов.
"
  (let* ((mods-dir (expand-file-name "emacs/base/modules" (file-name-directory (or load-file-name buffer-file-name))))
         (files (when (file-directory-p mods-dir) (directory-files mods-dir nil "^pro-.*\\.el$"))))
    (should (not (null files)))
    (dolist (f files)
      (let* ((bn (file-name-nondirectory f))
             (feat-name (intern (file-name-sans-extension bn))))
        (with-temp-message (format "requiring %s" feat-name)
          (should (require feat-name nil t))))))

;;; test-smoke-pro-modules.el ends here
