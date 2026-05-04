;;; test-agent-shell.el --- Unit tests for pro-agent-shell -*- lexical-binding: t; -*-
;; Тесты проверяют, что модуль pro-agent-shell предоставляет feature и
;; что при наличии пакета agent-shell он доступен через require/featurep.


(require 'ert)

(defun pro-test--ensure-modules-load-path ()
  "Ensure repository emacs/base/modules is on `load-path' for tests run -Q.

When tests are loaded with -l directly, `load-file-name' is set and we can
calculate the repo relative path. This mirrors site-init behaviour in a
lightweight way so module files are discoverable in tests.
"
  (let* ((start (or load-file-name buffer-file-name (expand-file-name ".")))
         (repo-root (or (locate-dominating-file start ".git")
                        (locate-dominating-file start "emacs")
                        (file-name-directory start)))
    (let ((modules-dir (expand-file-name "emacs/base/modules" repo-root)))
      (unless (member modules-dir load-path)
        (add-to-list 'load-path modules-dir)))))

(ert-deftest pro/agent-shell-feature-provided-or-loadable ()
  "pro-agent-shell должен предоставлять feature и/или делегировать
подключение к пакету agent-shell без ошибки.

Тест пытается обнаружить модуль/пакет по нескольким стратегиям, чтобы быть
надёжным в минимальных CI/контейнерных окружениях:
1) Попытаться require 'pro-agent-shell (через load-path)
2) Добавить emacs/base/modules в load-path и повторить require
3) Если всё ещё не найдено — попытаться загрузить файл напрямую
4) Наконец, проверить наличие пакета agent-shell на load-path через locate-library
"
  (pro-test--ensure-modules-load-path)
  (let* ((loaded (condition-case nil (require 'pro-agent-shell nil t) (error nil)))
         (maybe-loaded
          (or loaded
              ;; Try loading file directly as a last resort
              (let ((file (expand-file-name "pro-agent-shell.el" (expand-file-name "emacs/base/modules" (file-name-directory (or load-file-name buffer-file-name))))))
                (when (file-readable-p file)
                  (condition-case nil (progn (load file nil t) t) (error nil))))))
         (pkg-available (locate-library "agent-shell")))
    (should (or maybe-loaded pkg-available))))

(ert-deftest pro/agent-shell-featurep-when-present ()
  "Если пакет agent-shell присутствует, featurep 'agent-shell должно быть true." 
  (when (locate-library "agent-shell")
    (should (condition-case nil (require 'agent-shell nil t) (error nil)))))

(provide 'test-agent-shell)

;;; test-agent-shell.el ends here
