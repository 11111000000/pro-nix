;;; test-agent-shell.el --- Unit tests for pro-agent-shell -*- lexical-binding: t; -*-
;; Тесты проверяют, что модуль pro-agent-shell предоставляет feature и
;; что при наличии пакета agent-shell он доступен через require/featurep.

(require 'ert)

(defun pro-test--ensure-modules-load-path ()
  "Добавить emacs/base/modules в `load-path' если он обнаружим в репозитории.

Функция вычисляет корень репозитория относительно `load-file-name',
`buffer-file-name' или текущей директории и добавляет каталог
emacs/base/modules в `load-path' если он ещё не присутствует.
"
  (let* ((start (or load-file-name buffer-file-name default-directory))
         (repo-root (or (locate-dominating-file start ".git")
                        (locate-dominating-file start "emacs")
                        (file-name-directory start)))
    (when repo-root
      (let ((modules-dir (expand-file-name "emacs/base/modules" repo-root)))
        (unless (member modules-dir load-path)
          (add-to-list 'load-path modules-dir))))))

(ert-deftest pro/agent-shell-feature-provided-or-loadable ()
  "pro-agent-shell должен предоставлять feature и/или делегировать
подключение к пакету agent-shell без ошибки.

Тест старается быть устойчивым в минимальных CI/контейнерах:
1) гарантировать, что emacs/base/modules в load-path
2) попытаться require 'pro-agent-shell
3) в крайнем случае загрузить файл pro-agent-shell.el напрямую
4) проверить наличие пакета agent-shell через locate-library
"
  (pro-test--ensure-modules-load-path)
  (let* ((loaded (condition-case nil (require 'pro-agent-shell nil t) (error nil)))
         (maybe-loaded (or loaded
                           ;; last resort: load file directly from repo
                           (let ((file (expand-file-name "emacs/base/modules/pro-agent-shell.el"
                                                         (or (locate-dominating-file default-directory ".git")
                                                             (file-name-directory (or load-file-name buffer-file-name default-directory))))))
                             (when (and file (file-readable-p file))
                               (condition-case nil (progn (load file nil t) t) (error nil))))))
         (pkg-available (locate-library "agent-shell")))
    (should (or maybe-loaded pkg-available))))

(ert-deftest pro/agent-shell-featurep-when-present ()
  "Если пакет agent-shell присутствует, require должен успешно выполнить загрузку." 
  (when (locate-library "agent-shell")
    (should (condition-case nil (require 'agent-shell nil t) (error nil)))))

(provide 'test-agent-shell)

;;; test-agent-shell.el ends here
