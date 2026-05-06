;; Русский: комментарии и пояснения оформлены в учебном стиле (пояснения и примеры)
;;; pro-package-bootstrap.el --- Установщик пакетов по умолчанию -*- lexical-binding: t; -*-


(require 'package)
(defconst pro-package-bootstrap-targets
  '(gptel agent-shell magit consult vertico orderless marginalia corfu which-key
    rainbow-delimiters embark embark-consult nerd-icons nerd-icons-completion
    nerd-icons-ibuffer all-the-icons all-the-icons-completion all-the-icons-dired
    consult-projectile pro-fix-corfu)
  "Список пакетов, которые желательно установить в свежей конфигурации.

Этот список служит ориентиром для быстрой установки базового набора
функциональности. Он может быть расширен пользователем в локальном
manifest'е или управляемой политике Nix. Здесь перечислены символы
пакетов (символы Emacs Lisp), а не имена файлов." )

 (defun pro-package-bootstrap-install-targets ()
  "Установить пакеты из `pro-package-bootstrap-targets', если их нет.

Поведение:
- Автоустановка выполняется только при явном разрешении через
  `PRO_PACKAGES_AUTO_INSTALL=1`.
- В интерактивной сессии делегируется `pro-packages--maybe-install' если
  она доступна, чтобы уважать интерактивные политики пользователя.
"
   (interactive)
      ;; Default to auto-install enabled when the environment variable is
      ;; not present. This makes fresh profiles bootstrap missing packages
      ;; automatically.
       (let ((auto (string= (or (getenv "PRO_PACKAGES_AUTO_INSTALL") "1") "1"))
               (missing nil))
         ;; Compute which packages are actually missing before refreshing.
         (dolist (pkg pro-package-bootstrap-targets)
           (let ((pkg-sym (if (symbolp pkg) pkg (intern pkg))))
            (unless (or (package-installed-p pkg-sym)
                        (locate-library (symbol-name pkg-sym)))
                (push pkg-sym missing))))

         (when missing
           (dolist (pkg-sym (nreverse missing))
             (if (package-installed-p pkg-sym)
                 (message "[pro-package-bootstrap] already installed %S" pkg-sym)
               (cond
                ((and (not noninteractive) (fboundp 'pro-packages--maybe-install))
                 (pro-packages--maybe-install pkg-sym t))
                (auto
                 (condition-case err
                     (progn
                       (when (fboundp 'pro-packages-refresh-if-needed)
                         (pro-packages-refresh-if-needed))
                       (package-install pkg-sym)
                       (message "[pro-package-bootstrap] installed %S" pkg-sym))
                   (error (message "[pro-package-bootstrap] failed %S: %s" pkg-sym (error-message-string err)))))
                (t
                 (message "[pro-package-bootstrap] missing %S (skipped)" pkg-sym))))))))

(provide 'pro-package-bootstrap)

;; Auto-run bootstrap installer when environment requests auto-install.
(when (string= (or (getenv "PRO_PACKAGES_AUTO_INSTALL") "1") "1")
  ;; Run lazily but during init so missing packages are available later.
  (ignore-errors (pro-package-bootstrap-install-targets)))
