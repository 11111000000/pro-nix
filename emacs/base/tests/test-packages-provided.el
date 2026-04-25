;;; test-packages-provided.el --- Проверки доступности пакетов и настроек -*- lexical-binding: t; -*-
;; Тесты: убедиться, что важные пакеты доступны через Nix или runtime
;; и что ключевые настройки (dired, projectile, agent-shell) применены.

(require 'ert)

;; Загрузка вспомогательных модулей если они присутствуют в окружении теста.
(ignore-errors (require 'pro-packages nil t))
(ignore-errors (require 'pro-site-init nil t))
;; Ensure pro-packages-provided-by-nix is loaded from repository fallback when
;; home-manager hasn't generated ~/.config/emacs/provided-packages.el in test
;; environments (CI/container). The repository contains a fallback copy.
(let ((repo-provided (expand-file-name "emacs/base/provided-packages.el" (file-name-directory (or load-file-name buffer-file-name)))))
  (when (and (not (boundp 'pro-packages-provided-by-nix)) (file-exists-p repo-provided))
    (load repo-provided nil t)))

;; Ensure pro-packages installs common fallbacks when running tests in CI
(when (fboundp 'pro-packages-ensure-required)
  (ignore-errors (pro-packages-ensure-required)))

;; Try to auto-install a small set of known optional helpers that are
;; often missing in minimal environments but useful for integrations.
(when (fboundp 'pro-packages--maybe-install)
  (dolist (pkg '(dash-docs eldoc-box embark-consult consult-dash))
    (ignore-errors (pro-packages--maybe-install pkg t))))

(ert-deftest pro/test-agent-shell-available-or-declared-nix ()
  "Если agent-shell указан в списке предоставляемых Nix пакетов,
он должен быть доступен на `load-path'. Иначе — допускается установка
через package.el; в отсутствии обоих — тест пропускается с объяснением.
"
  (let ((declared (and (boundp 'pro-packages-provided-by-nix)
                       (memq 'agent-shell pro-packages-provided-by-nix)))
        (lib-path (locate-library "agent-shell")))
    (cond
     (declared
      (should lib-path))
      ;; Если не заявлен в Nix, попробуем хотя бы require без ошибки
     ((or lib-path (require 'agent-shell nil t))
      (should (or lib-path (featurep 'agent-shell))))
     (t (ert-skip "agent-shell не доступен и не заявлен в pro-packages-provided-by-nix")))))

(ert-deftest pro/test-projectile-provided-and-enabled-if-present ()
  "Проверить, что projectile либо предоставлен Nix'ом, либо доступен в runtime.
Если он заявлен в pro-packages-provided-by-nix — обязательно должен быть на load-path.
"
  (let ((declared (and (boundp 'pro-packages-provided-by-nix)
                       (memq 'projectile pro-packages-provided-by-nix)))
        (lib-path (locate-library "projectile")))
    (when declared
      (should lib-path))
    (if (or lib-path (require 'projectile nil t))
        (progn
          ;; Если загрузился — убедимся, что ключевые функции доступны
          (should (or (fboundp 'projectile-find-file) (fboundp 'projectile-mode)))
          ;; Если есть projectile-mode — включим/проверим переключатель
          (when (fboundp 'projectile-mode)
            (projectile-mode 1)
            (should (bound-and-true-p projectile-mode))))
      (ert-skip "projectile не доступен в этом окружении"))))

(ert-deftest pro/test-dired-defaults-and-icons ()
  "Проверить базовые настройки dired и интеграцию иконок (если доступна).
Тесты терпимы: если графические иконки недоступны — это не ошибка, но
см. сообщение для оператора.
"
  (require 'dired)
  ;; Ожидаемые switches по умолчанию
  (should (string= dired-listing-switches "-aBhlv --group-directories-first"))
  ;; dired-hide-details-mode должен присутствовать в hook'е
  (should (member 'dired-hide-details-mode dired-mode-hook))

  ;; Иконки: если treemacs-icons-dired доступен — он должен быть включён в hook
  (let ((treemacs-available (or (and (boundp 'pro-packages-provided-by-nix)
                                     (memq 'treemacs-icons-dired pro-packages-provided-by-nix))
                                (locate-library "treemacs-icons-dired"))))
    (if treemacs-available
        (should (member 'treemacs-icons-dired-enable-once dired-mode-hook))
      (ert-skip "treemacs-icons-dired не доступен; иконки в dired опущены"))))

(provide 'test-packages-provided)

;;; test-packages-provided.el ends here
