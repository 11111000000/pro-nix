;;; ert-soft-reload.el --- ERT tests for soft reload -*- lexical-binding: t; -*-
;;
;; Проверяет наличие и работоспособность pro-reload.el
;;
;; Контракт:
;;   pro/reload-module: перезагружает отдельный модуль
;;   pro/reload-all-modules: перезагружает все модули
;;   pro/session-save-and-restart-emacs: сохраняет сессию и перезапускает Emacs
;;

(require 'pro-reload)

(ert-deftest pro-test-reload-module-exists ()
  "Test pro/reload-module function exists."
  (should (fboundp 'pro/reload-module)))

(ert-deftest pro-test-reload-all-modules-exists ()
  "Test pro/reload-all-modules function exists."
  (should (fboundp 'pro/reload-all-modules)))

(ert-deftest pro-test-save-and-restart-exists ()
  "Test pro/session-save-and-restart-emacs function exists."
  (should (fboundp 'pro/session-save-and-restart-emacs)))

(provide 'ert-soft-reload)

;;; ert-soft-reload.el ends here