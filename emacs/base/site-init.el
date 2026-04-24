;;; site-init.el --- pro Emacs base -*- lexical-binding: t; -*-

(defvar pro-emacs-base-default-modules
  ;; Список модулей по умолчанию. Все системные модули именуются с префиксом
  ;; "pro-" для явности и однозначности. Пользовательский manifest может
  ;; по-прежнему перечислять имена без префикса; ниже мы канонизируем имена
  ;; так, чтобы site-init работал предсказуемо.
  '(pro-core pro-ui pro-packages pro-package-bootstrap pro-project pro-git pro-nix pro-js pro-ai pro-agent-shell pro-exwm pro-keys pro-nav pro-completion pro-terminals pro-windows pro-tabs))
(defvar pro-emacs-base-system-modules-dir nil)
(defvar pro-emacs-base-user-modules-dir (expand-file-name "~/.config/emacs/modules"))
(defvar pro-emacs-base-user-manifest (expand-file-name "~/.config/emacs/modules.el"))
(defvar pro-emacs-base-disable-marker (expand-file-name "~/.config/emacs/.disable-nixos-base"))

(defun pro-emacs-base--canonical-name (name)
  "Каноническое имя модуля NAME.

Если пользователь в manifest указал имя без префикса `pro-`, добавляем
префикс. Если имя уже содержит префикс, возвращаем как есть. NAME может
быть символом или строкой — возвращается строка.
"
  (let ((s (if (symbolp name) (symbol-name name) (format "%s" name))))
    (if (string-prefix-p "pro-" s) s (concat "pro-" s))))

(defun pro-emacs-base--module-file (dir name)
  "Построить путь к файлу модуля DIR и NAME (NAME канонизируется).
Если файл не найден — возвращается путь, который будет проверён вызовом
`file-readable-p` у вызывающего кода.
"
  (let ((canonical (pro-emacs-base--canonical-name name)))
    (expand-file-name (format "%s.el" canonical) dir)))

(defun pro-emacs-base--manifest-modules ()
  (if (file-exists-p pro-emacs-base-user-manifest)
      (progn
        (load-file pro-emacs-base-user-manifest)
        (cond
         ((boundp 'pro-emacs-modules) pro-emacs-modules)
         ((boundp 'my-emacs-modules) my-emacs-modules)
         ((boundp 'pro-emacs-base-modules) pro-emacs-base-modules)
         (t pro-emacs-base-default-modules)))
    pro-emacs-base-default-modules))

;; Load Nix-provided package facts early if present.
(let ((provided (expand-file-name "provided-packages.el" (expand-file-name ".config/emacs/" (getenv "HOME")))))
  (when (file-exists-p provided)
    (load provided nil t)))

;; If the user-managed provided-packages file is not present or is read-only
;; (for example when managed by home-manager), attempt to load a repository
;; fallback so development and containerized runs can still pick up the
;; emacs packages list generated from nix/provided-packages.nix.
(unless (and (file-exists-p (expand-file-name "provided-packages.el" (expand-file-name ".config/emacs/" (getenv "HOME"))))
             (file-writable-p (expand-file-name "provided-packages.el" (expand-file-name ".config/emacs/" (getenv "HOME")))) )
  (let ((base (file-name-directory (or load-file-name buffer-file-name)))
        (repo-provided (expand-file-name "emacs/base/provided-packages.el" (file-name-directory (or load-file-name buffer-file-name)))))
    (when (file-readable-p repo-provided)
      (load repo-provided nil t)
      (message "[pro-site-init] loaded repository-provided packages from %s" repo-provided))))

;; If site-init is loaded directly (for testing or containerized runs) try to
;; locate and load the system support modules (pro-compat, pro-packages)
;; from the repository so modules relying on pro--package-provided-p and
;; helpers work even when init.el didn't preload them.
(unless pro-emacs-base-system-modules-dir
  (let ((base (file-name-directory (or load-file-name buffer-file-name))))
    (setq pro-emacs-base-system-modules-dir (expand-file-name "modules" base))))

(let ((compat (expand-file-name "pro-compat.el" pro-emacs-base-system-modules-dir))
      (packages (expand-file-name "pro-packages.el" pro-emacs-base-system-modules-dir)))
  (when (file-readable-p compat)
    (load compat nil t))
  (when (file-readable-p packages)
    (load packages nil t)))

(defun pro-emacs-base--resolve-module (name)
  (let ((user-file (pro-emacs-base--module-file pro-emacs-base-user-modules-dir name))
        (system-file (and pro-emacs-base-system-modules-dir
                          (pro-emacs-base--module-file pro-emacs-base-system-modules-dir name))))
    ;; Prefer a user module only when it is readable and owned by the current
    ;; user. This avoids accidentally loading repository-local copies that are
    ;; owned by root (for example, deployed by an operator) which can cause
    ;; confusing startup-time failures and make debugging harder. If the user
    ;; file exists but is not owned by the current user, prefer the system
    ;; module when available and emit a diagnostic message.
    (let* ((user-readable (file-readable-p user-file))
           (user-owner-ok (when user-readable
                            (let ((attrs (file-attributes user-file)))
                              (and attrs (= (nth 2 attrs) (user-uid)))))))
      (cond
       ((and user-readable user-owner-ok) user-file)
       ((and user-readable (not user-owner-ok))
        (message "[pro-emacs] user module %s exists but is not owned by current user; preferring system module if available" user-file)
        (when (and pro-emacs-base-system-modules-dir
                   (not (file-exists-p pro-emacs-base-disable-marker))
                   (file-readable-p system-file))
          system-file))
       ((and pro-emacs-base-system-modules-dir
             (not (file-exists-p pro-emacs-base-disable-marker))
             (file-readable-p system-file)) system-file)
       (t
        (message "[pro-emacs] module lookup failed: %s user=%s system=%s" name user-file system-file)
        nil)))))

(defun pro-emacs-base-start ()
  (let ((modules (pro-emacs-base--manifest-modules)))
    (dolist (module modules)
      (let* ((module-name (if (symbolp module) (symbol-name module) module))
             (user-file (pro-emacs-base--module-file pro-emacs-base-user-modules-dir module-name))
             (system-file (and pro-emacs-base-system-modules-dir
                               (pro-emacs-base--module-file pro-emacs-base-system-modules-dir module-name))))
        ;; If the feature is already provided by an installed package (for
        ;; example org from ELPA), prefer the package's feature and skip
        ;; loading the repository-local module unless the user explicitly
        ;; manages a local module file. This avoids shadowing full-featured
        ;; packages with lightweight local config files that do not provide
        ;; the expected symbols.
        (cond
         ((and (not (file-readable-p user-file))
               (condition-case nil (require (intern module-name) nil t) (error nil)))
          (message "[pro-emacs] skipping module %s; feature provided by package" module-name))
         ((file-readable-p user-file)
          (load user-file nil t))
         ((and pro-emacs-base-system-modules-dir
               (not (file-exists-p pro-emacs-base-disable-marker))
               (file-readable-p system-file))
          (load system-file nil t))
         (t
          (message "[pro-emacs] missing module: %s" module-name)))))
    (message "[pro-emacs] loaded modules: %S" modules)
    ;; После загрузки всех модулей попробуем применить отложенные биндинги
    ;; клавиш (если модуль keys был загружен и оставил pending записи).
    (when (fboundp 'pro-keys-apply-pending)
      (ignore-errors (pro-keys-apply-pending)))
    (when (fboundp 'pro-keys-report-pending)
      (ignore-errors (pro-keys-report-pending)))))

(provide 'pro-site-init)
