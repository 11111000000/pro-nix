;;; pro-packages.el --- prompt-and-install package flow -*- lexical-binding: t; -*-
;; Назначение: минимальный движок для интерактивной установки пакетов когда Nix их не предоставляет.
;;
;; Контракт:
;; - pro-packages--maybe-install / pro/packages-ensure — публичные точки входа для проверки/установки пакетов.
;; - Политика: Nix-provided > runtime > MELPA (с явным allowlist) > package-vc (last resort).
;; - Побочные эффекты: модификация `package-alist' и возможная запись файла решений пользователя `pro-packages-decisions-file`.
;;
;; Proof: headless ERT (emacs/base/tests/*) и ручные smoke-тесты через scripts/emacs-pro-wrapper.sh
;; Last reviewed: 2026-05-02

(require 'package)
(require 'subr-x)

(defvar pro-packages-decisions-file
  (expand-file-name "decisions.el" (expand-file-name ".config/emacs/" (getenv "HOME")))
  "User decisions file (alist of (pkg . decision)).")

(defvar pro-packages-decisions nil
  "Alist of package decisions: (pkg . (always|never)).")

(defvar pro-packages--refreshed nil
  "Non-nil once package-archives have been refreshed in this session.")

(defun pro-packages--load-decisions ()
  "Load decisions from `pro-packages-decisions-file` if present." 
  (when (file-exists-p pro-packages-decisions-file)
    (condition-case _err
        (load-file pro-packages-decisions-file)
      (error (message "[pro-packages] failed to load decisions")))))

(defun pro-packages--save-decisions ()
  "Persist `pro-packages-decisions` into `pro-packages-decisions-file` atomically." 
  (let ((dir (file-name-directory pro-packages-decisions-file)))
    (unless (file-directory-p dir) (make-directory dir t)))
  (with-temp-file (concat pro-packages-decisions-file ".tmp")
    (prin1 `(setq pro-packages-decisions ',pro-packages-decisions) (current-buffer)))
  (condition-case _err
      (rename-file (concat pro-packages-decisions-file ".tmp") pro-packages-decisions-file t)
    (error (message "[pro-packages] failed to save decisions"))))

(defun pro--package-provided-p (pkg)
  "Return non-nil if PKG is available in this Emacs session.

This checks only for actual availability: installed packages or library
presence on `load-path'. Do NOT treat `pro-packages-provided-by-nix' as a
guarantee of availability — that list is advisory and describes what Nix
should provide, but it may be out of sync in some environments (eg. during
tests/containers). Use `pro--package-declared-by-nix-p' to query the
declaration separately.
"
  (or (package-installed-p pkg)
      (locate-library (symbol-name pkg))))

(defun pro--package-declared-by-nix-p (pkg)
  "Return non-nil if PKG is declared in `pro-packages-provided-by-nix'.
This is advisory only and does not imply the package is present on the
current `load-path'."
  (and (boundp 'pro-packages-provided-by-nix)
       (memq pkg pro-packages-provided-by-nix)))

(defun pro-packages--ask-user (pkg)
  "Prompt the user for how to handle missing PKG.
Return symbol: 'install, 'always, 'never or 'cancel." 
  (let ((prompt (format "Package %s is not provided by Nix. Install from MELPA? [i]nstall/[a]lways/[s]kip/[c]ancel: " pkg)))
    (pcase (read-char-choice prompt '(?i ?a ?s ?c))
      (?i 'install)
      (?a 'always)
      (?s 'never)
      (?c 'cancel))))

(defun pro-packages--do-install (pkg)
  "Install PKG via package.el. Refresh archives once per session if needed.
Return t on success." 
  (unless pro-packages--refreshed
    (condition-case _e
        (progn (package-refresh-contents) (setq pro-packages--refreshed t))
      (error (message "[pro-packages] failed to refresh package archives"))))
  (condition-case err
      (progn
        (package-install pkg)
        (message "[pro-packages] installed %s" pkg)
        t)
    (error (message "[pro-packages] failed to install %s: %s" pkg err) nil)))

;; Mapping of package -> ("owner/repo" . "revision") for packages that are
;; commonly unavailable on ELPA but can be fetched directly from GitHub.
;; Keep the VC fallback list minimal and explicit. We do not attempt
;; arbitrary package-vc installs unless the operator explicitly allows
;; auto-install and a trusted repo is configured here. Empty by default.
(defvar pro-packages-vc-fallback-alist
  '()
  "Alist mapping package symbols to GitHub repo and revision for package-vc fallback.")

;; Map of package -> list of dependency symbols that should be attempted
;; installed after a successful package-vc install. This is a pragmatic
;; developer convenience for packages that declare deps not present in the
;; runtime. Keep minimal and explicit.
(defvar pro-packages-vc-deps
  '((agent-shell . (acp shell-maker)))
  "Alist mapping VC-installed package symbols to their runtime dependencies.")

(defvar pro-packages-auto-install-allowlist
  '()
  "List of package symbols that are allowed to be auto-installed from MELPA
when PRO_PACKAGES_AUTO_INSTALL=1. Keeps automatic network installs small and
predictable. Empty by default — operator must opt-in to specific packages.")

;; Developer conveniences (allowlist and VC fallbacks) were used during
;; iterative development to bootstrap packages that were later added to the
;; Nix overlay. In production/CI we prefer strict, declarative behaviour:
;; PRO_PACKAGES_AUTO_INSTALL is disabled by default and no implicit VC
;; fallbacks are present. If you need to enable a dev-only fallback, edit
;; `pro-packages-auto-install-allowlist' or `pro-packages-vc-fallback-alist'
;; in a local configuration outside the repository.

;; Keep allowlist and VC fallbacks empty by default for reproducibility.
(setq pro-packages-auto-install-allowlist '())
(setq pro-packages-vc-fallback-alist '())

(defun pro-packages--maybe-install (pkg &optional allow-melpa)
  "Ensure PKG is available. If missing and ALLOW-MELPA is non-nil, prompt-and-install.
Return t if PKG is now available (installed or provided)." 
  ;; Backwards-compatible wrapper routed to the central policy function
  ;; `pro/packages-ensure'. Keep this thin so existing call sites keep
  ;; working until modules are migrated to use the clearer API.
  (pro/packages-ensure pkg allow-melpa))


(defun pro/packages-ensure (pkg &optional allow-melpa)
  "Ensure PKG is available following the policy: Nix -> runtime -> MELPA -> Git.

If PKG is declared in `pro-packages-provided-by-nix' we expect it to be
present on `load-path' (Nix must provide it). If it's present, return t.
If it is declared by Nix but missing, signal an error — this is a
configuration problem and should be fixed declaratively.

If the package is not declared by Nix, try to require it from the current
runtime. If present — return t. If absent, and ALLOW-MELPA is non-nil and
`PRO_PACKAGES_AUTO_INSTALL` is enabled, attempt to install from package.el.
If that fails, consult `pro-packages-vc-fallback-alist` and try a package-vc
install from a pinned GitHub repo. Return t on success, nil otherwise.
"
  (let ((declared (pro--package-declared-by-nix-p pkg)))
    (cond
     ;; Declared in Nix: must be present on load-path; otherwise it's a
     ;; configuration error — surface it so CI fails instead of masking.
     (declared
      (if (pro--package-provided-p pkg)
          t
        (error "Package %s is declared in Nix but not available at runtime. Fix your Nix profile." pkg)))

     ;; Runtime already provides it
     ((pro--package-provided-p pkg) t)

     ;; Not provided: consider installing from MELPA if allowed by env/arg
    ((and allow-melpa (string= (or (getenv "PRO_PACKAGES_AUTO_INSTALL") "0") "1")
          (memq pkg pro-packages-auto-install-allowlist))
     ;; Only auto-install from MELPA if pkg is explicitly allowlisted.
     (when (pro-packages--do-install pkg)
       (progn (ignore-errors (require pkg nil t)) (pro--package-provided-p pkg))))

     ;; Not in MELPA or not allowed; last resort: package-vc from pinned repo
     ((and (assoc pkg pro-packages-vc-fallback-alist) (fboundp 'package-vc-install))
      (let* ((entry (cdr (assoc pkg pro-packages-vc-fallback-alist)))
             (repo (car entry))
             (rev (cdr entry))
             (url (format "https://github.com/%s" repo)))
        (condition-case _err
            (progn
              (package-vc-install url)
              (ignore-errors (require pkg nil t))
              ;; Try to install small runtime deps for this VC package if known
              (dolist (d (cdr (assoc pkg pro-packages-vc-deps)))
                (when (and (boundp 'pro-packages-auto-install-allowlist)
                           (memq d pro-packages-auto-install-allowlist)
                           (string= (or (getenv "PRO_PACKAGES_AUTO_INSTALL") "0") "1"))
                  (ignore-errors (pro-packages--do-install d))))
              (pro--package-provided-p pkg))
          (error (message "[pro-packages] package-vc failed for %s" pkg) nil))))

     ;; Nothing worked
     (t nil))))


;; User-facing convenience wrappers (commands) used by keybindings.
(defun pro-packages-install (pkg)
  "Интерактивно установить PKG (символ или строка) через package.el.
PKG может быть символом или строкой. Эта команда вызывает
`pro-packages--do-install' после обновления архивов при необходимости." 
  (interactive (list (intern (completing-read "Install package: " (mapcar #'symbol-name (mapcar #'car package-alist)) nil nil))))
  (let ((sym (if (symbolp pkg) pkg (intern (format "%s" pkg)))))
    (if (pro-packages--do-install sym)
        (message "pro-packages: installed %s" sym)
      (message "pro-packages: failed to install %s" sym))))

(defun pro-packages-install-vc (pkg)
  "Установить PKG из VCS если доступно. Использует package-vc если есть." 
  (interactive (list (read-string "Install VC package (name or recipe): ")))
  (if (fboundp 'package-vc-install)
      (condition-case err
          (progn (package-vc-install pkg) (message "pro-packages: package-vc-install %s" pkg))
        (error (message "pro-packages: package-vc-install failed: %S" err)))
    (message "pro-packages: package-vc not available; try manual install")))

(defun pro-packages-refresh ()
  "Обновить списки архивов (package-refresh-contents)." 
  (interactive)
  (condition-case err
      (progn (package-refresh-contents) (message "pro-packages: refreshed package archives") t)
    (error (message "pro-packages: refresh failed: %S" err) nil)))

(defun pro-packages-upgrade-all ()
  "Переустановить/обновить все установленные пакеты до доступных версий.
Это простая реализация: обновляем archive и переустанавливаем пакеты
из списка `package-alist'." 
  (interactive)
  (pro-packages-refresh)
  (let ((pkgs (mapcar #'car package-alist)))
    (dolist (p pkgs)
      (when (and (symbolp p) (not (memq p '(package package-elpa))))
        (condition-case err
            (progn (package-install p) (message "pro-packages: upgraded %s" p))
          (error (message "pro-packages: failed to upgrade %s: %S" p err))))))
  (message "pro-packages: upgrade-all done"))

(defun pro-packages-upgrade-built-ins ()
  "Попытка обновить встроенные/system-provided пакеты — синоним pro-packages-upgrade-all.
Резервная реализация: вызывает `pro-packages-upgrade-all'." 
  (interactive)
  (message "pro-packages: upgrade-built-ins (delegating to upgrade-all)")
  (pro-packages-upgrade-all))

(defun pro-packages-menu ()
  "Показать список пакетов (package-list-packages).
Удобно вызывать из keybinding C-c P p." 
  (interactive)
  (if (fboundp 'package-list-packages)
      (package-list-packages)
    (message "pro-packages: package-list-packages not available")))

;;; Дополнительные утилиты
(defun pro-packages-ensure-required (&optional packages)
  "Убедиться, что PACKAGES (список символов) доступны.
Если PACKAGES не передан, используется набор рекомендуемых пакетов
для профиля pro-nix. Пакеты, помеченные в `pro-packages-provided-by-nix`
считаются уже предоставленными и не устанавливаются через MELPA.
" 
  (interactive)
    (let* ((defaults '(consult corfu cape treemacs projectile expand-region yasnippet consult-yasnippet consult-eglot kind-icon vterm exwm eldoc-box mmm-mode))
          (wanted (or packages defaults))
          (provided (when (boundp 'pro-packages-provided-by-nix) pro-packages-provided-by-nix)))
    (dolist (p wanted)
      ;; Try to require the package first, even if Nix claims to provide it.
      ;; In development/container runs the Nix-provided packages may not be
      ;; on `load-path', so we fall back to MELPA install via
      ;; `pro-packages--maybe-install' when require fails.
      (message "pro-packages: ensure candidate %s (provided-by-nix=%S)" p (memq p provided))
      (unless (condition-case _ (require p nil t) (error nil))
        ;; Not require-able: attempt to install if allowed
        (when (pro-packages--maybe-install p t)
          (ignore-errors (require p nil t))))))
    t)

(provide 'pro-packages)

;;; pro-packages.el ends here
