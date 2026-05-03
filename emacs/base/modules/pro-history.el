;;; pro-history.el --- Runtime file layout and backup/autosave policies -*- lexical-binding: t; -*-
;; Назначение: централизованная политика хранения временных файлов, backup-ов
;; и пользовательского state для pro-Emacs.
;; Контракт:
;; - выносит state в XDG-подобный layout:
;;   - state:   ${XDG_STATE_HOME:-~/.local/state}/pro-emacs/
;;   - cache:   ${XDG_CACHE_HOME:-~/.cache}/pro-emacs/
;; - не добавляет data-каталоги в `load-path`.
;; - на этапе загрузки создает необходимые каталоги в idempotent-режиме.
;; Побочные эффекты: модифицируетEmacs переменные backup/auto-save/savehist/recentf/save-place.
;; Проверка: emacs/base/tests/test-history.el (headless ERT)

(require 'subr-x)

(defgroup pro-history nil
  "pro: runtime history and temp file policies."
  :group 'convenience)

(defcustom pro-history-xdg-state-home
  (or (and (getenv "XDG_STATE_HOME") (expand-file-name (getenv "XDG_STATE_HOME")))
      (expand-file-name "~/.local/state"))
  "Base directory for durable state."
  :type 'directory
  :group 'pro-history)

(defcustom pro-history-xdg-cache-home
  (or (and (getenv "XDG_CACHE_HOME") (expand-file-name (getenv "XDG_CACHE_HOME")))
      (expand-file-name "~/.cache"))
  "Base directory for cache/temporary files."
  :type 'directory
  :group 'pro-history)

(defvar pro-history-state-directory
  (expand-file-name "pro-emacs/" pro-history-xdg-state-home)
  "Directory for durable pro-emacs state (backups, savehist, recentf, places, sessions).")

(defvar pro-history-cache-directory
  (expand-file-name "pro-emacs/" pro-history-xdg-cache-home)
  "Directory for pro-emacs cache (auto-save, temp, logs).")

(defvar pro-history-backup-directory
  (expand-file-name "backups/" pro-history-state-directory)
  "Directory where Emacs stores backup files.")

(defvar pro-history-auto-save-directory
  (expand-file-name "auto-save/" pro-history-cache-directory)
  "Directory where Emacs stores auto-save files.")

(defvar pro-history-auto-save-list-directory
  (expand-file-name "auto-save-list/" pro-history-cache-directory)
  "Directory where Emacs stores auto-save-list files.")

(defvar pro-history-session-directory
  (expand-file-name "sessions/" pro-history-state-directory)
  "Directory for session snapshots and pro/session files.")

(defun pro-history-state-file (&rest parts)
  "Return a path under `pro-history-state-directory' joined with PARTS." 
  (let ((base pro-history-state-directory))
    (expand-file-name (mapconcat 'identity parts "/") base)))

(defun pro-history-cache-file (&rest parts)
  "Return a path under `pro-history-cache-directory' joined with PARTS." 
  (let ((base pro-history-cache-directory))
    (expand-file-name (mapconcat 'identity parts "/") base)))

(defun pro-history-ensure-directories ()
  "Ensure all pro-history directories exist (idempotent)."
  (dolist (d (list pro-history-state-directory
                   pro-history-backup-directory
                   pro-history-session-directory
                   pro-history-cache-directory
                   pro-history-auto-save-directory
                   pro-history-auto-save-list-directory))
    (unless (file-directory-p d)
      (make-directory d t))))

(defun pro-history-describe-paths ()
  "Return alist of important pro-history paths." 
  `((state . ,pro-history-state-directory)
    (cache . ,pro-history-cache-directory)
    (backups . ,pro-history-backup-directory)
    (auto-save . ,pro-history-auto-save-directory)
    (auto-save-list . ,pro-history-auto-save-list-directory)
    (sessions . ,pro-history-session-directory)))

;; Configure backup policy
(defun pro-history-configure-backups ()
  "Apply backup-directory-alist and related settings." 
  (setq backup-directory-alist `((".*" . ,pro-history-backup-directory)))
  (setq make-backup-files t)
  (setq backup-by-copying t)
  (setq version-control t)
  (setq delete-old-versions t)
  (setq kept-new-versions 25)
  (setq kept-old-versions 5)
  (setq vc-make-backup-files t)
  ;; leave create-lockfiles as nil by default to avoid .# files unless explicitly desired
  (setq create-lockfiles nil))

;; Configure auto-save
(defun pro-history-configure-auto-save ()
  "Apply auto-save policy: send auto-saves to cache directory." 
  (setq auto-save-default t)
  (setq auto-save-timeout 20)
  (setq auto-save-interval 200)
  (setq auto-save-file-name-transforms
        `((".*" ,(concat (file-name-as-directory pro-history-auto-save-directory) "\1") t)))
  (setq auto-save-list-file-prefix
        (expand-file-name ".saves-" pro-history-auto-save-list-directory)))

;; Configure savehist
(defun pro-history-configure-savehist ()
  "Configure savehist to use state directory." 
  (ignore-errors (require 'savehist))
  (setq savehist-file (pro-history-state-file "savehist.el"))
  (setq savehist-autosave-interval nil)
  (setq savehist-additional-variables
        '(search-ring regexp-search-ring extended-command-history
                      projectile-project-command-history kill-ring compile-command
                      file-name-history shell-command-history))
  (when (fboundp 'savehist-mode)
    (savehist-mode 1)))

;; Configure recentf
(defun pro-history-configure-recentf ()
  "Configure recentf to use state directory and exclude pro internals." 
  (ignore-errors (require 'recentf))
  (setq recentf-save-file (pro-history-state-file "recentf.el"))
  (setq recentf-max-saved-items 500)
  (setq recentf-auto-cleanup 'never)
  (setq recentf-exclude
        `(,pro-history-state-directory
          ,pro-history-cache-directory
          "/\\.git/"
          "/\\.emacs\\.d/elpa/"
          "-autoloads\\.el\\'"
          "\\.elc\\'"
          "\\.eln\\'"
          "/TAGS\\'")))

;; Configure save-place
(defun pro-history-configure-saveplace ()
  "Configure save-place to use state directory." 
  (ignore-errors (require 'saveplace))
  (setq save-place-file (pro-history-state-file "places.el"))
  (when (fboundp 'save-place-mode)
    (save-place-mode 1)))

;; Top-level initializer
(defun pro-history-initialize ()
  "Initialize pro-history: create dirs and apply policies." 
  (pro-history-ensure-directories)
  (pro-history-configure-backups)
  (pro-history-configure-auto-save)
  (pro-history-configure-savehist)
  (pro-history-configure-recentf)
  (pro-history-configure-saveplace)
  ;; Defensive: ensure we do not add data dirs to load-path
  (when (member pro-history-state-directory load-path)
    (setq load-path (remove pro-history-state-directory load-path)))
  (when (member pro-history-cache-directory load-path)
    (setq load-path (remove pro-history-cache-directory load-path)))
  (message "pro-history: initialized (state=%s cache=%s)" pro-history-state-directory pro-history-cache-directory))

;; Initialize at load
(pro-history-initialize)

(provide 'pro-history)

;;; pro-history.el ends here
