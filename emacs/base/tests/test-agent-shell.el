;;; test-agent-shell.el --- Unit tests for pro-agent-shell -*- lexical-binding: t; -*-
;; Тесты проверяют, что модуль pro-agent-shell предоставляет feature и
;; что при наличии пакета agent-shell он доступен через require/featurep.

(require 'ert)

(defun pro-test--ensure-modules-load-path ()
  "Добавить emacs/base/modules в `load-path', если каталог обнаружим." 
  (let* ((start (or load-file-name buffer-file-name default-directory))
         (repo-root (or (locate-dominating-file start ".git")
                        (locate-dominating-file start "emacs")
                        (file-name-directory start))))
    (when repo-root
      (let ((modules-dir (expand-file-name "emacs/base/modules" repo-root)))
        (unless (member modules-dir load-path)
          (add-to-list 'load-path modules-dir))))))

(ert-deftest pro/agent-shell-feature-provided-or-loadable ()
  "pro-agent-shell должен быть загружаем без ошибки." 
  (pro-test--ensure-modules-load-path)
  (let* ((loaded (condition-case nil
                     (require 'pro-agent-shell nil t)
                   (error nil)))
         (pkg-available (locate-library "agent-shell")))
    (should (or loaded pkg-available))))

(ert-deftest pro/agent-shell-featurep-when-present ()
  "Если пакет agent-shell присутствует, require должен успешно выполниться." 
  (when (locate-library "agent-shell")
    (should (condition-case nil
                (require 'agent-shell nil t)
              (error nil)))))

(ert-deftest pro/agent-shell-pro-agent-open-command-exists ()
  "Модуль pro-agent-shell должен определять интерактивную команду pro-agent-open." 
  (pro-test--ensure-modules-load-path)
  (should (condition-case nil
              (require 'pro-agent-shell nil t)
            (error nil)))
  (should (fboundp 'pro-agent-open))
  (should (commandp 'pro-agent-open)))

(provide 'test-agent-shell)

;;; test-agent-shell.el ends here
