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


(ert-deftest pro-test-agents-launchable ()
  "Ensure the common agent CLIs are available and can be started.

This test checks that each expected agent executable is on `exec-path` and
that we can spawn it (using `start-process`). We use a harmless `--help`
argument where available; the objective is only to ensure the command
can be launched in this environment, not to validate its output."
  (dolist (cmd '("goose" "aider" "opencode"))
    (let ((exe (executable-find cmd)))
      ;; `should' takes the test form first and an optional message second.
      ;; The original call passed the message first which triggers eager
      ;; macro-expansion errors. Use the executable as the test and the
      ;; formatted string as the failure message.
      (unless exe
        (ert-fail (format "%s is not on PATH" cmd)))
      (condition-case err
          (let ((proc (start-process (concat "pro-test-" cmd) nil exe "--help")))
            (should (processp proc))
            ;; If the process is still running, kill it to avoid leaks.
            (when (process-live-p proc)
              (ignore-errors (kill-process proc))
              (ignore-errors (delete-process proc))))
        ;; On error we want the test to fail and present a helpful message,
        ;; so assert nil with the formatted message as the failure text.
        (error (ert-fail (format "failed to start %s: %s" cmd (error-message-string err))))))))

(ert-deftest pro-test-keys-suite ()
  "Run keys unit tests." 
  (let ((tests-file (expand-file-name "emacs/base/modules/tests-keys.el" (pro-test--repo-root))))
    (when (file-readable-p tests-file)
      (load tests-file nil t)))

(provide 'tests)
