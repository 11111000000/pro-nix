;;; pro-package-bootstrap.el --- Установщик пакетов по умолчанию -*- lexical-binding: t; -*-


(require 'package)
(defconst pro-package-bootstrap-targets
  '(gptel agent-shell agent-shell-hud magit consult vertico orderless marginalia corfu which-key
    rainbow-delimiters embark embark-consult nerd-icons nerd-icons-completion
    nerd-icons-ibuffer
    consult-projectile pro-fix-corfu)
  "Список пакетов, которые желательно установить в свежей конфигурации.

Этот список служит ориентиром для быстрой установки базового набора
функциональности. Он может быть расширен пользователем в локальном
manifest'е или управляемой политике Nix. Здесь перечислены символы
пакетов (символы Emacs Lisp), а не имена файлов.

`http-server' намеренно отсутствует: он поставляется через Nix-рецепт
(`nix/emacs-recipes/http-server.nix') как propagatedInput для `emcp' и
недоступен в MELPA/ELPA. Если Nix-пакет не подключён — agent-shell-hud
и emcp будут ругаться на отсутствующий `http-server' feature; решение —
добавить `http-server' в `pro.emacs.providedPackages'." )

(defun pro-package-bootstrap-install-targets ()
  "Установить пакеты из `pro-package-bootstrap-targets', которых нет в runtime.

Команда: `M-x pro-package-bootstrap-install-targets' (C-c P a).

Поведение:
- Команда НЕ выполняется автоматически при старте Emacs. Emacs загружается
  на основе Nix-профиля (EMACSLOADPATH) и уже установленных пакетов.
- Если какого-то базового пакета не хватает — функция выводит список
  недостающих в `*Messages*` и устанавливает их из MELPA (один refresh
  архивов за сессию, дальше кэшируется в
  `pro-packages-refresh-stamp-file`).
- В интерактивной сессии делегирует установку `pro-packages--maybe-install'
  если она доступна, чтобы уважать интерактивные политики пользователя.
- Не-interactive вызов (например, из startup) — безопасно завершается без
  сетевого обмена, пока пользователь сам не запросит установку.
"
  (interactive)
  (let ((missing nil))
    ;; Compute which packages are actually missing before any network I/O.
    (dolist (pkg pro-package-bootstrap-targets)
      (let ((pkg-sym (if (symbolp pkg) pkg (intern pkg))))
        (unless (or (package-installed-p pkg-sym)
                    (locate-library (symbol-name pkg-sym)))
          (push pkg-sym missing))))
    (if (null missing)
        (message "[pro-package-bootstrap] all bootstrap targets are available")
      (message "[pro-package-bootstrap] missing %d bootstrap target(s): %s"
               (length missing)
               (mapconcat #'symbol-name (nreverse missing) ", "))
      (dolist (pkg-sym (nreverse missing))
        (cond
         ((package-installed-p pkg-sym)
          (message "[pro-package-bootstrap] already installed %S" pkg-sym))
         ((and (not noninteractive) (fboundp 'pro-packages--maybe-install))
          (pro-packages--maybe-install pkg-sym t))
         (t
          (condition-case err
              (progn
                (when (fboundp 'pro-packages-refresh-if-needed)
                  (pro-packages-refresh-if-needed))
                (package-install pkg-sym)
                (message "[pro-package-bootstrap] installed %S" pkg-sym))
            (error (message "[pro-package-bootstrap] failed %S: %s"
                            pkg-sym (error-message-string err))))))))))

(provide 'pro-package-bootstrap)

;; Auto-run on startup is intentionally disabled. Emacs starts from the
;; Nix-provided profile (EMACSLOADPATH). If a base package is missing, the
;; user installs it on demand via `M-x pro-package-bootstrap-install-targets'
;; (bound to C-c P a in emacs-keys.org). This avoids hitting MELPA on every
;; launch when no packages are actually missing.
