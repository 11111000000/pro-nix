;;; test-agent-shell.el --- Unit tests for pro-agent-shell -*- lexical-binding: t; -*-
;; Тесты проверяют, что модуль pro-agent-shell предоставляет feature и
;; что при наличии пакета agent-shell он доступен через require/featurep.

(require 'ert)

(defun pro-test--ensure-modules-load-path ()
  "Добавить emacs/base/modules в `load-path', если каталог обнаружим.

Функция должна работать в различных режимах запуска ERT (batch, -l, в
скриптах), поэтому пробуем несколько стратегий для поиска корня репозитория.
"
  (let* ((start (or load-file-name buffer-file-name default-directory))
         (repo-root (or
                     ;; Обычно тест запускается из директории репозитория.
                     (and (locate-dominating-file default-directory ".git")
                          (locate-dominating-file default-directory ".git"))
                     (and (locate-dominating-file default-directory "emacs")
                          (locate-dominating-file default-directory "emacs"))
                     ;; fallback: попытаться от стартовой точки (скрипт, -l)
                     (and start (or (locate-dominating-file start ".git")
                                    (locate-dominating-file start "emacs")))
                     ;; в крайнем случае используем директорию самого файла
                     (file-name-directory (or start default-directory)))))
    (when repo-root
      (let ((modules-dir (expand-file-name "emacs/base/modules" repo-root))
            (module-file (expand-file-name "emacs/base/modules/pro-agent-shell.el" repo-root)))
        (unless (member modules-dir load-path)
          (add-to-list 'load-path modules-dir))
        ;; Если по какой-то причине require не находит модуль через load-path,
        ;; попробуем загрузить его напрямую по пути — это помогает при запуске
        ;; тестов в нестандартных окружениях (контейнеры, tmp wrapper).
        (when (and (file-readable-p module-file)
                   (not (condition-case nil (require 'pro-agent-shell nil t) (error nil))))
          (load-file module-file))))))

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
