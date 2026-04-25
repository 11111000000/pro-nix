;;; test-smoke-pro-modules.el --- Smoke test: require all pro-* modules -*- lexical-binding: t; -*-
;;
;; Русский: тест, требующий наличия всех модулей pro-*.el. Тест запущен
;; в CI/--batch и не должен вызывать интерактивные промпты — для этого мы
;; используем (require FEATURE nil t) чтобы получить non-nil/false без ошибок.
;;
;; Результат теста: успех, если все модули предоставляют свои префиксные
;; фичи и могут быть require'd в чистой среде.

(require 'ert)

(ert-deftest pro-smoke/require-all-modules ()
  "Require all emacs/base/modules/pro-*.el modules without error.

Используется `require` в безопасном режиме (без интерактивных установок).
"
  (let* ((mods-dir (expand-file-name "emacs/base/modules"
                                    (file-name-directory (or load-file-name buffer-file-name))))
         (files (when (file-directory-p mods-dir)
                  (directory-files mods-dir nil "^pro-.*\\.el$"))))
    (should (not (null files)))
    (dolist (f files)
      (let* ((bn (file-name-nondirectory f))
             (feat-name (intern (file-name-sans-extension bn))))
        (with-temp-message (format "requiring %s" feat-name)
          (should (require feat-name nil t)))))))

;;; test-smoke-pro-modules.el ends here
