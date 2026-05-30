;;; pro-exwm.el --- EXWM session glue for pro-nix -*- lexical-binding: t; -*-
;;
;; Layers:
;;  1. Session detection — XDG_CURRENT_DESKTOP must contain "exwm"
;;  2. EXWM startup — exwm-wm-mode, systemtray, X input method
;;  3. Global keys — s-1..s-6 для вкладок; прочие из emacs-keys.org
;;  4. Buffer naming — exwm-update-title-hook → «TITLE — CLASS»
;;
;; EXWM is provided via Nix (emacsPackages.exwm + emacsPackages.xelb)
;; so require succeeds immediately — no MELPA fallback needed.

;; ── Buffer naming ────────────────────────────────────────────────────────

(defun pro-exwm--buffer-name-from-title ()
  "Set the buffer name of the current EXWM buffer to the window title.

When title is non-nil, rename buffer to «TITLE — CLASS» where CLASS
is the WM_CLASS class-name (e.g. «firefox»).  If title is absent,
fall back to class only."
  (when (and (boundp 'exwm-title)
             (boundp 'exwm-class-name))
    (let* ((title exwm-title)
           (class exwm-class-name)
           (name (cond
                  ((and title class (> (length title) 0))
                   (format "%s — %s" title class))
                  (class class)
                  (title title)
                  (t (buffer-name)))))
      (when (and name (fboundp 'exwm-workspace-rename-buffer))
        (exwm-workspace-rename-buffer name)))))

(defun pro-exwm-install-title-rename-hook ()
  "Install the title→buffer rename hook."
  (when (boundp 'exwm-update-title-hook)
    (add-hook 'exwm-update-title-hook #'pro-exwm--buffer-name-from-title)))

;; ── Global keys ──────────────────────────────────────────────────────────

(defconst pro-exwm-super-tab-keys
  (let ((keys nil))
    (dotimes (i 6)
      (let ((tab (1+ i)))
        (push (cons (kbd (format "s-%d" tab))
                    `(lambda () (interactive) (tab-bar-select-tab ,tab)))
              keys)))
    (nreverse keys))
  "Глобальные клавиши EXWM для переключения вкладок (s-1..s-6).")

(defun pro-exwm--apply-global-keys ()
  "Собрать глобальные EXWM-клавиши с учётом базового слоя.

Использует `exwm-input-global-keys' (официальная переменная EXWM),
которая перехватывает нажатия ДО того, как они дойдут до приложения."
  (when (boundp 'exwm-input-global-keys)
    (setq exwm-input-global-keys
          (append pro-exwm-super-tab-keys
                  (and (boundp 'pro-keys-exwm-global-keys)
                       pro-keys-exwm-global-keys)))))

;; ── Session detection ────────────────────────────────────────────────────

(defun pro-exwm--session-p ()
  "Проверить, что Emacs запущен как EXWM-сессия.

Проверяет содержит ли XDG_CURRENT_DESKTOP значение `exwm' (регистронезависимо).
GDM может добавлять префикс \='none+' к имени сессии."
  (let ((desktop (downcase (or (getenv "XDG_CURRENT_DESKTOP") ""))))
    (or (string= desktop "exwm")
        (string-match-p "^none\\+exwm$" desktop)
        (string-match-p "^exwm:" desktop))))

;; ── EXWM startup ─────────────────────────────────────────────────────────

(defun pro-exwm-start-session ()
  "Запустить EXWM, если это EXWM-сеанс.

Выполняет полную инициализацию:
  - Активирует exwm-wm-mode (основной оконный менеджер)
  - Включает exwm-systemtray-mode (системный трей)
  - Запускает exwm-xim (X Input Method для ввода поверх приложений)
  - Применяет глобальные клавиши перехвата
  - Настраивает переименование буферов"
  (interactive)
  (when (pro-exwm--session-p)
    ;; EXWM is provided by Nix — require should succeed immediately.
    (condition-case err
        (require 'exwm)
      (error
       (message "[pro-exwm] failed to load EXWM: %s" err)
       (cl-return-from pro-exwm-start-session)))

    ;; Configure EXWM before activating the minor mode.
    ;; exwm-wm-mode reads these variables during init.
    (setq exwm-workspace-number 4)

    ;; Apply global keys BEFORE exwm-wm-mode init (idempotent — mode
    ;; reads the variable once).
    (pro-exwm--apply-global-keys)

    ;; Apply simulation keys (Emacs keys in X apps) BEFORE exwm-wm-mode init.
    ;; exwm--init calls exwm-input--init which reads exwm-input-simulation-keys
    ;; ONCE; changing it afterwards has no effect.  exwm-init-hook fires AFTER
    ;; input-init so it is too late — we must set simulation keys here.
    (when (fboundp 'pro/exwm-apply-default-simulation-keys)
      (pro/exwm-apply-default-simulation-keys))

    ;; Install title→buffer rename hook (runs on every title update).
    (pro-exwm-install-title-rename-hook)

    ;; Enable system tray BEFORE exwm-wm-mode so tray starts with the WM.
    ;; exwm-systemtray-mode is autoloaded from the exwm package.
    (condition-case nil
        (require 'exwm-systemtray)
      (error nil))
    (when (fboundp 'exwm-systemtray-mode)
      (exwm-systemtray-mode 1))

    ;; Enable X Input Method (IME) for multi-language text input in X apps.
    ;; This is what makes layout switching work in Firefox, terminals, etc.
    (condition-case nil
        (require 'exwm-xim)
      (error nil))
    (when (fboundp 'exwm-xim-mode)
      (exwm-xim-mode 1))

    ;; Start the window manager.  exwm-wm-mode is idempotent — calling it
    ;; when already enabled is a no-op.
    ;; When EXWM exits, kill Emacs — we ARE the session.
    (add-hook 'exwm-exit-hook #'kill-emacs)
    (exwm-wm-mode 1)
    (message "[pro-exwm] session started (workspaces: %d, systemtray: %s, xim: %s)"
             exwm-workspace-number
             (if (and (boundp 'exwm-systemtray-mode) exwm-systemtray-mode) "on" "off")
             (if (and (boundp 'exwm-xim-mode) exwm-xim-mode) "on" "off"))))

;; ── Init hooks ───────────────────────────────────────────────────────────
;;
;; `window-setup-hook' fires after Emacs has created the initial frame
;; but before it is displayed.  This is the canonical time to start
;; the window manager — the display is ready but the user hasn't seen
;; anything yet.

(add-hook 'window-setup-hook #'pro-exwm-start-session)

;; When pro-keys module finishes loading, re-apply global keys so any
;; keys registered via pro/register-module-keys (exwm layer) take effect.
(with-eval-after-load 'pro-keys
  (when (pro-exwm--session-p)
    (pro-exwm--apply-global-keys)))

(provide 'pro-exwm)

;;; pro-exwm.el ends here