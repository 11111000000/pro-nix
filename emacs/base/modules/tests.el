;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; tests.el --- headless ERT tests -*- lexical-binding: t; -*-

(require 'ert)

(defvar pro-test-repo-root nil)
(defvar pro-test--load-errors nil)

(defun pro-test--repo-root ()
  "Вернуть корень репозитория для headless-запуска."
  (or pro-test-repo-root
      (file-name-directory (directory-file-name default-directory))))

(defun pro-test--safe-load (file)
  "Load FILE and collect any error."
  (condition-case err
      (progn
        (load file nil t)
        t)
    (error
     (push (format "%s: %s" file (error-message-string err)) pro-test--load-errors)
     nil)))

(defun pro-test-load-base (modules-dir)
  "Load base Emacs modules from MODULES-DIR and return errors."
  (setq pro-test--load-errors nil)
  (dolist (file '("core.el" "ui.el" "packages.el" "package-bootstrap.el" "keys.el" "nav.el" "ai.el" "agent.el" "chat.el"))
    (pro-test--safe-load (expand-file-name file modules-dir)))
  (nreverse pro-test--load-errors))

(ert-deftest pro-test-load-base-modules ()
  "Base modules should load in a disposable Emacs."
  (let ((errors (pro-test-load-base (expand-file-name "emacs/base/modules" (pro-test--repo-root)))))
    (should (null errors))))

(ert-deftest pro-test-core-basics ()
  "Core defaults must stay predictable."
  (load (expand-file-name "emacs/base/modules/core.el" (pro-test--repo-root)) nil t)
  (should (null indent-tabs-mode))
  (should (equal fill-column 88))
  (should (eq ring-bell-function 'ignore)))

(ert-deftest pro-test-nav-loads-when-available ()
  "Navigation module should not signal in headless mode."
  (should (pro-test--safe-load (expand-file-name "emacs/base/modules/nav.el" (pro-test--repo-root)))))

(ert-deftest pro-test-ai-json-present ()
  "AI model catalog should be present and readable."
  (let ((json (expand-file-name "emacs/base/modules/ai-models.json" (pro-test--repo-root))))
    (should (file-readable-p json))))

(provide 'tests)
