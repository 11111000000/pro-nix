;;; site-init.el --- pro Emacs base -*- lexical-binding: t; -*-

;; Список модулей по умолчанию. Все системные модули именуются с префиксом
;; "pro-" для явности и однозначности. Пользовательский manifest может
;; по-прежнему перечислять имена без префикса; ниже мы канонизируем имена
;; так, чтобы site-init работал предсказуемо.
;;
;; Решение: по просьбе пользователя — включаем все модули из emacs/base/modules
;; в список модулей по умолчанию. Это делает конфигурацию более явной и
;; гарантирует, что все помощники и адаптеры будут загружены при старте.
(defvar pro-emacs-base-default-modules
    '(pro-core pro-ui pro-packages pro-package-bootstrap pro-project pro-git
    pro-nix pro-js pro-ai pro-ai-ellama pro-ai-anvil pro-agent-shell pro-emcp pro-c pro-chat pro-telega pro-compat
    pro-completion pro-completion-keys pro-consult-helpers pro-dired
    pro-app-launcher pro-clipboard
    pro-emacs-check-fonts pro-exwm-sim pro-exwm pro-feeds pro-fix-corfu
    pro-haskell pro-java pro-key-utils pro-keys pro-lisp pro-markdown pro-nix-refresh
    pro-org pro-python pro-reload pro-session pro-history pro-spell pro-startup-metrics pro-profiler pro-tabs
    pro-terminals pro-test-helpers pro-tests pro-text
    pro-ui-completion pro-ui-fonts pro-ui-fringes pro-ui-icons
    pro-ui-improvements pro-buffer-banner pro-ui-modeline pro-ui-theme pro-ui-tty
    pro-dashboard pro-help pro-windows-popups
    pro-vterm-theme pro-windows pro-nav pro-docker
    pro-key-prefixes pro-treemacs)
  "Полный список модулей, загружаемых по умолчанию при старте Emacs.")
(defvar pro-emacs-base-system-modules-dir nil)
(defvar pro-emacs-base-user-modules-dir (expand-file-name "~/.config/emacs/modules"))
(defvar pro-emacs-base-user-manifest (expand-file-name "~/.config/emacs/modules.el"))
(defvar pro-emacs-base-disable-marker (expand-file-name "~/.config/emacs/.disable-nixos-base"))

(defvar pro-emacs-base-lazy-modules
  '(pro-telega pro-feeds pro-docker pro-haskell pro-java pro-exwm-sim
    pro-ai-ellama pro-ai-anvil)
  "Modules deferred until first use.
Each module is loaded on demand via `pro-emacs-base-load-lazy-module'.
Modules listed here must `provide' a feature matching their name.

Why these are lazy:
  - `pro-telega'      : needs telega-server (TDLib JSON bridge), ~50 MB.
  - `pro-feeds'       : elfeed needs sqlite, periodic DB writes.
  - `pro-docker'      : docker-tramp + transient, only useful with docker.
  - `pro-haskell'     : haskell-mode + lsp, only for Haskell buffers.
  - `pro-java'        : lsp-java + eglot, only for Java buffers.
  - `pro-exwm-sim'    : sim-keymap only meaningful in EXWM.
  - `pro-ai-ellama'   : ellama + llm stack ~30+ .el files, only when user invokes.
  - `pro-ai-anvil'    : anvil.el ~100+ .el files, only when user invokes.")

(defun pro-emacs-base--canonical-name (name)
  "Каноническое имя модуля NAME как строка.

Если пользователь указал имя без префикса `pro-`, возвращается строка с
префиксом. Если имя уже содержит префикс, возвращается как есть. NAME может
быть символом или строкой.
"
  (let ((s (if (symbolp name) (symbol-name name) (format "%s" name))))
    (if (string-prefix-p "pro-" s) s (concat "pro-" s))))

(defun pro-emacs-base--module-file (dir name)
  "Найти файл модуля в DIR по NAME.

NAME может быть 'core' или 'pro-core' — функция нормализует имя и ищет
в следующем порядке: pro-<base>.el, <base>.el. Возвращается путь к первому
существующему файлу или nil, если ни один кандидат не найден.
"
    (let* ((s (if (symbolp name) (symbol-name name) (format "%s" name)))
           (base (if (string-prefix-p "pro-" s) (substring s 4) s))
           (cand-pro (expand-file-name (format "pro-%s.el" base) dir))
           (cand-plain (expand-file-name (format "%s.el" base) dir)))
      (cond
       ((file-readable-p cand-pro) cand-pro)
       ((file-readable-p cand-plain) cand-plain)
       ;; Return the canonical candidate path even when not present. This
       ;; simplifies callers which expect a string path for diagnostics and
       ;; loading logic; callers should still check readability before load.
       (t cand-pro))))

(defun pro-emacs-base--feature-provided-p (feature-name)
  "Проверить, предоставлена ли фича FEATURE-NAME.

Если FEATURE-NAME это строка вида "pro-foo", проверяем наличие провайда
и для варианта без префикса ("foo"), чтобы быть терпимыми к legacy
файлам, которые ещё не переименованы.
"
  (let* ((s (if (symbolp feature-name) (symbol-name feature-name) (format "%s" feature-name)))
         (sym (intern s))
         (alt (and (string-prefix-p "pro-" s) (intern (substring s 4)))))
    (or (condition-case nil (require sym nil t) (error nil))
        (and alt (condition-case nil (require alt nil t) (error nil))))))

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
    (let* ((user-readable (file-readable-p user-file))
           (user-dir-symlink (and pro-emacs-base-user-modules-dir
                                  (file-symlink-p pro-emacs-base-user-modules-dir)))
           (user-file-symlink (and user-readable (file-symlink-p user-file)))
           (user-attrs (when (and user-readable (null user-file-symlink))
                         (file-attributes user-file)))
           (user-owner-ok (or user-dir-symlink
                              user-file-symlink
                              (and user-attrs
                                   (= (nth 2 user-attrs) (user-uid))))))
      (cond
       ;; System file always wins when it exists and is not disabled.
       ;; The user-override path is reserved for users who explicitly
       ;; want to override a single module; if they want that, they
       ;; create a file in ~/.config/emacs/modules/ that is owned by
       ;; their own UID AND we fall back through this ladder in order.
       ((and pro-emacs-base-system-modules-dir
             (not (file-exists-p pro-emacs-base-disable-marker))
             (file-readable-p system-file))
        system-file)
       ((and user-readable user-owner-ok) user-file)
       ((and user-readable (not user-owner-ok))
        (message "[pro-emacs] user module %s exists but is not owned by current user; no system fallback available" user-file)
        nil)
       (t
        (message "[pro-emacs] module lookup failed: %s user=%s system=%s" name user-file system-file)
        nil)))))

(defun pro-emacs-base-load-lazy-module (module-name)
  "Load MODULE-NAME if it is in `pro-emacs-base-lazy-modules' and not yet loaded."
  (let ((sym (if (symbolp module-name) module-name (intern module-name))))
    (unless (featurep sym)
      (let ((resolved (pro-emacs-base--resolve-module (symbol-name sym))))
        (when resolved
          (condition-case err
              (load resolved nil t)
            (error
             (message "[pro-emacs] failed to lazy-load module %s: %S" module-name err))))))))

(defun pro-emacs-base-start ()
  (let ((modules (pro-emacs-base--manifest-modules)))
    (dolist (module modules)
      (let* ((module-name (if (symbolp module) (symbol-name module) module))
             (sym (intern module-name)))
        (if (memq sym pro-emacs-base-lazy-modules)
            (message "[pro-emacs] deferred lazy module: %s" module-name)
          (let ((resolved-file (pro-emacs-base--resolve-module module-name)))
            (if resolved-file
                (condition-case err
                    (load resolved-file nil t)
                  (error
                   (message "[pro-emacs] failed to load module %s: %S" resolved-file err)))
              (message "[pro-emacs] missing module: %s" module-name)))))))
    ;; After all modules loaded: reconstruct epistemic state
    (let ((epistemology-file (expand-file-name "pro-epistemology.el" pro-emacs-base-system-modules-dir)))
      (when (file-readable-p epistemology-file)
        (load epistemology-file nil t)
        (when (fboundp 'pro--reconstruct)
          (pro--reconstruct))))
    ;; После загрузки всех модулей попробуем применить отложенные биндинги
    ;; клавиш (если модуль keys был загружен и оставил pending записи).
    (when (fboundp 'pro-keys-apply-pending)
      (ignore-errors (pro-keys-apply-pending)))
    (when (fboundp 'pro-keys-report-pending)
      (ignore-errors (pro-keys-report-pending))))

(defun pro-emacs-base-report-loaded-modules (modules)
  "Log the module list after startup using MODULES from the caller."
  (message "[pro-emacs] loaded modules: %S" modules))

(provide 'pro-site-init)
