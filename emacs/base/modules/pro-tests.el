;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; tests.el --- headless ERT tests -*- lexical-binding: t; -*-

;; Guard against being loaded multiple times in the same Emacs process.
(unless (featurep 'pro-tests)

(require 'ert)

(defvar pro-test-repo-root nil)
(defvar pro-test--load-errors nil)

(defun pro-test--repo-root ()
  "Return the repository root for headless runs.

Try to locate the repo by looking for a .git directory or the emacs/ tree.
If those are not found, fall back to `default-directory'. This makes the
tests robust when invoked from different CWDs or from CI runners.
"
  (or pro-test-repo-root
      (let* ((start (or default-directory (expand-file-name ".")))
             (git-root (locate-dominating-file start ".git"))
             (emacs-root (locate-dominating-file start "emacs")))
        (or git-root emacs-root (expand-file-name start)))))

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
  (dolist (file '("pro-core.el" "pro-ui.el" "pro-packages.el" "pro-package-bootstrap.el" "pro-keys.el" "pro-nav.el" "pro-ai.el" "pro-agent-shell.el" "pro-chat.el"))
    (pro-test--safe-load (expand-file-name file modules-dir)))
  (nreverse pro-test--load-errors))

(unless (fboundp 'pro-test-load-base-modules)
  (ert-deftest pro-test-load-base-modules ()
    "Base modules should load in a disposable Emacs."
    (let ((errors (pro-test-load-base (expand-file-name "emacs/base/modules" (pro-test--repo-root)))))
      (should (null errors)))))

(unless (fboundp 'pro-test-core-basics)
  (ert-deftest pro-test-core-basics ()
    "Core defaults must stay predictable."
    (load (expand-file-name "emacs/base/modules/pro-core.el" (pro-test--repo-root)) nil t)
    ;; Some modules may change buffer-local `indent-tabs-mode' during init;
    ;; assert it is not enabled rather than testing for the precise nil/listness.
    (should (not indent-tabs-mode))
    (should (equal fill-column 88))
    (should (eq ring-bell-function 'ignore))))

  (unless (fboundp 'pro-test-nav-loads-when-available)
  (ert-deftest pro-test-nav-loads-when-available ()
    "Navigation module should not signal in headless mode."
    (should (pro-test--safe-load (expand-file-name "emacs/base/modules/pro-nav.el" (pro-test--repo-root))))))

(unless (fboundp 'pro-test-ai-json-present)
  (ert-deftest pro-test-ai-json-present ()
    "AI model catalog should be present and readable."
    (let ((json (expand-file-name "emacs/base/modules/ai-models.json" (pro-test--repo-root))))
      (should (file-readable-p json)))))


(unless (fboundp 'pro-test-agents-launchable)
  (ert-deftest pro-test-agents-launchable ()
    "Ensure the common agent CLIs are available and can be started.

This test verifies presence of helpful agent CLI tools but does not fail
the entire suite if they are not available in the environment. In CI
environments these tools may be absent; in that case the test is skipped
with a diagnostic message.
"
    (dolist (cmd '("goose" "aider" "opencode"))
      (let ((exe (executable-find cmd)))
        (if (null exe)
            (message "pro-test: skipping agent check, %s not on PATH" cmd)
          (condition-case err
              (let ((proc (start-process (concat "pro-test-" cmd) nil exe "--help")))
                (should (processp proc))
                (when (process-live-p proc)
                  (ignore-errors (kill-process proc))
                  (ignore-errors (delete-process proc))))
            (error (ert-fail (format "failed to start %s: %s" cmd (error-message-string err))))))))))

(unless (fboundp 'pro-test-keys-suite)
  (ert-deftest pro-test-keys-suite ()
    "Run keys unit tests." 
    (let ((tests-file (expand-file-name "emacs/base/modules/tests-keys.el" (pro-test--repo-root))))
      (when (file-readable-p tests-file)
        (load tests-file nil t)))))

 (provide 'pro-tests)
)
