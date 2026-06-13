;;; test-package-policy.el --- Проверки политики пакетов Emacs -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(ignore-errors (require 'pro-packages nil t))

(ert-deftest pro-packages/archives-configured-at-start ()
  "Архивы пакетов должны быть заданы без сетевого обновления."
  (when (fboundp 'pro-packages-configure-archives)
    (let ((package-archives nil))
      (pro-packages-configure-archives)
      (should (equal package-archives pro-packages-archives)))))

(ert-deftest pro-packages/initialize-does-not-refresh ()
  "Инициализация package.el не должна делать refresh архивов."
  (when (fboundp 'pro-packages-initialize)
    (let ((called nil))
      (cl-letf (((symbol-function 'package-initialize)
                 (lambda () (setq called t)))
                ((symbol-function 'package-refresh-contents)
                 (lambda () (ert-fail "package-refresh-contents must not run during initialize"))))
        (setq pro-packages--initialized nil)
        (pro-packages-initialize)
        (should called)))))

(ert-deftest pro-packages/runtime-package-beats-nix ()
  "Вручную/в runtime доступный пакет должен побеждать Nix-declaration."
  (when (fboundp 'pro/packages-ensure)
    (cl-letf (((symbol-function 'pro--package-runtime-available-p)
               (lambda (_pkg) t))
              ((symbol-function 'pro--package-declared-by-nix-p)
               (lambda (_pkg) t))
              ((symbol-function 'pro-packages--do-install)
               (lambda (_pkg) (ert-fail "install must not run for runtime package"))))
      (should (pro/packages-ensure 'consult t)))))

(ert-deftest pro-packages/refresh-only-on-install-path ()
  "Refresh архивов вызывается только перед реальной установкой отсутствующего пакета."
  (when (fboundp 'pro-packages--do-install)
    (let ((refresh-called nil)
          (install-called nil)
          (package-archives nil))
      (cl-letf (((symbol-function 'pro-packages-configure-archives)
                 (lambda () (setq package-archives pro-packages-archives)))
                ((symbol-function 'pro-packages-initialize)
                 (lambda () nil))
                ((symbol-function 'pro-packages-refresh-if-needed)
                 (lambda (&optional _force) (setq refresh-called t) t))
                ((symbol-function 'package-install)
                 (lambda (_pkg) (setq install-called t) t)))
        (setq pro-packages--refreshed nil)
        (should (pro-packages--do-install 'dummy))
        (should refresh-called)
        (should install-called)))))

(ert-deftest pro-package-bootstrap/no-refresh-when-nothing-missing ()
  "При уже доступных пакетах bootstrap не должен инициировать refresh."
  (when (fboundp 'pro-package-bootstrap-install-targets)
    (let ((refresh-called nil))
      (cl-letf (((symbol-function 'package-installed-p)
                 (lambda (_pkg) t))
                ((symbol-function 'locate-library)
                 (lambda (_name) t))
                ((symbol-function 'pro-packages-refresh-if-needed)
                 (lambda (&optional _force) (setq refresh-called t) t))
                ((symbol-function 'pro-packages--maybe-install)
                 (lambda (_pkg &optional _allow) (ert-fail "install must not run when package already exists"))))
        (let ((pro-packages--refreshed nil)
              (pro-packages-provided-by-nix nil)
              (process-environment process-environment)
              (noninteractive nil))
          (pro-package-bootstrap-install-targets)
          (should-not refresh-called))))))

(ert-deftest pro-package-bootstrap/refreshes-once-when-missing ()
  "Команда должна установить недостающие пакеты, обновив архивы один раз."
  (when (fboundp 'pro-package-bootstrap-install-targets)
    (let ((refresh-called 0)
          (install-called 0))
      (cl-letf (((symbol-function 'package-installed-p)
                 (lambda (_pkg) nil))
                ((symbol-function 'locate-library)
                 (lambda (_name) nil))
                ((symbol-function 'pro-packages-refresh-if-needed)
                 (lambda (&optional _force) (setq refresh-called (1+ refresh-called)) t))
                ((symbol-function 'package-install)
                 (lambda (_pkg) (setq install-called (1+ install-called)) t))
                ((symbol-function 'pro-packages-configure-archives)
                 (lambda () nil))
                ((symbol-function 'pro-packages-initialize)
                 (lambda () nil)))
        (let ((pro-packages--refreshed nil)
              (pro-packages-provided-by-nix nil)
              (process-environment process-environment)
              (noninteractive t))
          ;; Truncate bootstrap list for a deterministic single-package run.
          (let ((pro-package-bootstrap-targets '(dummy-test-pkg)))
            (pro-package-bootstrap-install-targets))
          (should (= 1 install-called))
          (should (= 1 refresh-called)))))))

(ert-deftest pro-package-bootstrap/no-autostart-on-load ()
  "Загрузка модуля не должна вызывать refresh архивов даже при пустой среде."
  (when (fboundp 'pro-packages-refresh-if-needed)
    (let ((refresh-called nil)
          (bootstrap-src (expand-file-name
                          "../modules/pro-package-bootstrap.el"
                          (file-name-directory
                           (symbol-file #'ert-deftest)))))
      (cl-letf (((symbol-function 'pro-packages-refresh-if-needed)
                 (lambda (&optional _force) (setq refresh-called t) t))
                ((symbol-function 'package-refresh-contents)
                 (lambda () (ert-fail "package-refresh-contents must not run on load"))))
        (let ((process-environment '()))
          ;; Loading the module from source — no MELPA read should happen
          ;; regardless of PRO_PACKAGES_AUTO_INSTALL being unset/0/1.
          (let ((features-before features))
            (when (file-readable-p bootstrap-src)
              (load bootstrap-src nil t))
            (should-not refresh-called)
            (should (memq 'pro-package-bootstrap features))
            (should (memq 'pro-package-bootstrap features-before))))))))

(provide 'test-package-policy)

;;; test-package-policy.el ends here
