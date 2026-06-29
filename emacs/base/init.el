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
  ;; Allow package.el to upgrade Emacs built-in packages when needed.
  ;; Magit and other packages sometimes require newer releases of built-ins
  ;; (notably `transient`). Setting this here makes non-interactive upgrades
  ;; possible during startup when we explicitly request them below.
  (setq package-install-upgrade-built-in t)

   ;; NOTE: modules dir is already on `load-path' via early-init.el.
   ;; Now load site-init which will load configured modules
  (load (expand-file-name "site-init.el" base-dir) nil t)
  ;; First-start bootstrap: один раз (marker-based) устанавливает transient
  ;; и declared-пакеты через MELPA. На обычных запусках marker существует,
  ;; и функция no-op'ит — никаких сетевых запросов к MELPA.
  ;; Заменил прежний безусловный `pro-packages--do-install 'transient' (он
  ;; опрашивал MELPA на каждом старте).
  (when (fboundp 'pro-emacs-maybe-bootstrap-on-first-start)
    (pro-emacs-maybe-bootstrap-on-first-start))
  (pro-emacs-base-start)

  ;; Test loader: only in headless/CI runs. We use env var instead of a
  ;; test-mode feature so production Emacs does not even read tests/.
  ;; scripts/test-emacs-headless.sh sets PRO_EMACS_TEST_MODE=1; nothing
  ;; else should. This unblocks the 16 test-*.el files that had no
  ;; loader (audit-2026-06-18 P1-8).
  (when (getenv "PRO_EMACS_TEST_MODE")
    (let* ((tests-dir (expand-file-name "tests" base-dir))
           (loaded (make-hash-table :test 'equal)))
      (when (file-directory-p tests-dir)
        (dolist (f (sort (directory-files tests-dir t "\\.el$") #'string<))
          ;; Skip test-loader self-reference (no test-loader.el yet) and
          ;; any file that fails to load — surface the error.
          (unless (gethash f loaded)
            (puthash f t loaded)
            (load f nil t)))))))

(provide 'pro-init)

;; After core init: load optional completion keys and external org key loader
(when (require 'pro-completion-keys nil t)
  ;; pro-completion-keys binds useful C-c o <letter> keys for CAPE and consult-yasnippet
  )

;; External references to other personal repositories (like ~/pro) are
;; intentionally disallowed in pro-nix. Global keys must come from
;; emacs-keys.org (system) and ~/.config/emacs/keys.org (user).
;; If you need to import keys, port them into the repository or into
;; your per-user ~/.config/emacs/keys.org; do not reference ~/pro here.
