;;; ert-session.el --- ERT tests for session serialization -*- lexical-binding: t; -*-
;;
;; Проверяет наличие и работоспособность pro-session.el
;;
;; Контракт:
;;   pro/session-save: сохраняет buffer/point/window state
;;   pro/session-restore: восстанавливает сохранённое состояние
;;

(require 'pro-session)

(ert-deftest pro-test-session-save-exists ()
  "Test pro/session-save function exists."
  (should (fboundp 'pro/session-save)))

(ert-deftest pro-test-session-restore-exists ()
  "Test pro/session-restore function exists."
  (should (fboundp 'pro/session-restore)))

(ert-deftest pro-test-session-save-returns-path ()
  "Test pro/session-save returns a file path."
  (let ((saved-file (pro/session-save)))
    (should (stringp saved-file))
    (when (and saved-file (file-exists-p saved-file))
      (delete-file saved-file))))

(provide 'ert-session)

;;; ert-session.el ends here