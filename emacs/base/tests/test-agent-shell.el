;;; test-agent-shell.el --- Unit tests for pro-agent-shell -*- lexical-binding: t; -*-
;; Тесты проверяют, что модуль pro-agent-shell предоставляет feature и
;; что при наличии пакета agent-shell он доступен через require/featurep.

(require 'ert)

(ert-deftest pro/agent-shell-feature-provided-or-loadable ()
  "pro-agent-shell должен предоставлять feature и/или делегировать
подключение к пакету agent-shell без ошибки."
  (let ((loaded (condition-case nil (require 'pro-agent-shell nil t) (error nil)))
        (pkg-available (locate-library "agent-shell")))
    (should (or loaded pkg-available))))

(ert-deftest pro/agent-shell-featurep-when-present ()
  "Если пакет agent-shell присутствует, featurep 'agent-shell должно быть true." 
  (when (locate-library "agent-shell")
    (should (condition-case nil (require 'agent-shell nil t) (error nil)))))

(provide 'test-agent-shell)

;;; test-agent-shell.el ends here
