;;; init.el --- pro Emacs loader -*- lexical-binding: t; -*-

;; Название: emacs/base/init.el — Основная загрузка pro-Emacs
;; Кратко: выставляет user-emacs-directory, загружает pro-compat/pro-packages и стартует site-init.
;;
;; Цель: безопасно и предсказуемо поднять site-init и базовые pro-модули в окружении Nix/Home-Manager.
;; Контракт: не менять глобальные user-emacs-directory вне явного пользовательского override; записывает custom-file в пользовательскую директорию.
;; Побочные эффекты: может привести к автоустановке пакетов при первом запуске, если пакеты отсутствуют.
;; Proof: headless ERT (emacs/base/tests/*) и ./scripts/emacs-pro-wrapper.sh smoke tests.
;; Last reviewed: 2026-05-02

(let ((base-dir (file-name-directory (or load-file-name buffer-file-name))))
  (setq user-emacs-directory (file-name-as-directory (expand-file-name "~/.config/emacs/")))
  ;; Ensure Emacs customizations are written to a user-writable file under
  ;; user-emacs-directory rather than (by default) into the main init file
  ;; which in Nix/Home‑Manager setups may live in a read-only /nix/store.
  (setq custom-file (expand-file-name "custom.el" user-emacs-directory))
  (when (file-exists-p custom-file)
    (load custom-file nil t))
  (setq pro-emacs-base-system-modules-dir (expand-file-name "modules" base-dir))
  ;; Load pro-compat and pro-packages early so modules can consult them
  (when (file-readable-p (expand-file-name "pro-compat.el" pro-emacs-base-system-modules-dir))
    (load (expand-file-name "pro-compat.el" pro-emacs-base-system-modules-dir) nil t))
  (when (file-readable-p (expand-file-name "pro-packages.el" pro-emacs-base-system-modules-dir))
    (load (expand-file-name "pro-packages.el" pro-emacs-base-system-modules-dir) nil t))
  (when (fboundp 'pro-packages-configure-archives)
    (pro-packages-configure-archives))
  (when (fboundp 'pro-packages-initialize)
    (pro-packages-initialize))
  ;; Обязательно добавляем каталог модулей в `load-path' — это делает
  ;; локальные вспомогательные пакеты (pro-*) доступными для `require' и
  ;; `locate-library' в ранней стадии загрузки.
  (when (file-directory-p pro-emacs-base-system-modules-dir)
    (add-to-list 'load-path pro-emacs-base-system-modules-dir))
  ;; Now load site-init which will load configured modules
  (load (expand-file-name "site-init.el" base-dir) nil t)
  ;; Ensure a set of required packages are available before modules perform
  ;; package-driven installs. This helps avoid race conditions where package
  ;; installation/compilation of one package (eg. nix-mode) requires another
  ;; package (eg. mmm-mode) to be present during compilation. Install the
  ;; defaults noninteractively when possible.
  (when (require 'pro-packages nil t)
    (ignore-errors (when (fboundp 'pro-packages-ensure-required)
                     (pro-packages-ensure-required))))
  (pro-emacs-base-start))

(provide 'pro-init)

;; After core init: load optional completion keys and external org key loader
(when (require 'completion-keys nil t)
  ;; completion-keys binds useful C-c o <letter> keys for CAPE and consult-yasnippet
  )

;; External references to other personal repositories (like ~/pro) are
;; intentionally disallowed in pro-nix. Global keys must come from
;; emacs-keys.org (system) and ~/.config/emacs/keys.org (user).
;; If you need to import keys, port them into the repository or into
;; your per-user ~/.config/emacs/keys.org; do not reference ~/pro here.
