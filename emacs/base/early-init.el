(;;; early-init.el --- pro Emacs bootstrap -*- lexical-binding: t; -*-

;; Название: emacs/base/early-init.el — Ранний bootstrap Emacs
;; Кратко: ранняя инициализация pro-Emacs: базовые переменные package, load-path и GUI-hygiene.
;;
;; Цель: минимально вмешиваться в ранний этап загрузки Emacs, чтобы обеспечить
;;  воспроизводимую загрузку модулей из репозитория и избежать записи в read-only init files.
;; Контракт: изменяет только Emacs ранние переменные (package-*, frame-*), добавляет pro modules в load-path.
;; Побочные эффекты: выставляет PRO_PACKAGES_AUTO_INSTALL=1 по умолчанию (можно переопределить внешней переменной окружения).
;; Proof: headless ERT и smoke checks: scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el
;; Last reviewed: 2026-05-03

(setq package-enable-at-startup nil)
(setq package-quickstart-file (expand-file-name "quickstart.el" user-emacs-directory))
(setq package-quickstart-sync nil)
(setq frame-inhibit-implied-resize t)
(setq inhibit-splash-screen t)

;; Ensure local pro modules directory is on `load-path' as early as possible.
;; This prevents the bootstrap installer from attempting to install helper
;; modules that are shipped with the repo (for example pro-fix-corfu).
;; We compute the path relative to this file so the code works when the
;; repository is used directly as the Emacs site-lisp source.
(let* ((this-dir (file-name-directory (or load-file-name buffer-file-name)))
       (pro-modules-dir (expand-file-name "modules" this-dir)))
  (when (file-directory-p pro-modules-dir)
    (add-to-list 'load-path pro-modules-dir)))

;; Enable noninteractive auto-install of missing pro packages by default.
;; This environment variable is checked by pro-packages--maybe-install and
;; used to auto-install packages from MELPA when appropriate.
;; По умолчанию включаем автоустановку пакетов, но уважаем внешнюю
;; установку переменной окружения чтобы позволить CI/локальные запуски
;; отключать автоприём (например PRO_PACKAGES_AUTO_INSTALL=0).
(unless (getenv "PRO_PACKAGES_AUTO_INSTALL")
  (setenv "PRO_PACKAGES_AUTO_INSTALL" "1"))

(provide 'pro-early-init)

;; Early GUI hygiene: hide distracting GUI chrome as soon as possible.
;; Guarded to avoid errors in TTY. This is intentionally minimal and
;; safe to call from early-init (before packages are loaded).
(when (display-graphic-p)
  (when (fboundp 'menu-bar-mode) (menu-bar-mode -1))
  (when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
  (when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
  ;; Thin window divider to give subtle separation between windows.
  (when (fboundp 'window-divider-mode)
    (setq window-divider-default-bottom-width 1
          window-divider-default-places 'bottom-only)
    (window-divider-mode 1)))

;; Attempt to load the default theme early if configured by ui-theme.
;; This reduces a white/black flash when Emacs starts in GUI. Loading is
;; safe and guarded inside ui-theme module.
(ignore-errors
  (when (require 'ui-theme nil t)
    (when (fboundp 'pro-ui-load-default-theme-if-set)
      (pro-ui-load-default-theme-if-set))))
