;;; pro-exwm.el --- EXWM session glue for pro-nix -*- lexical-binding: t; -*-
;;
;; Layers:
;;  1. Session detection — XDG_CURRENT_DESKTOP must contain "exwm"
;;  2. EXWM startup — exwm-wm-mode, systemtray, X input method
;;  3. Global keys — s-1..s-6 для вкладок; прочие из emacs-keys.org
;;  4. Buffer naming — exwm-update-title-hook → «TITLE — CLASS»
;;  5. Input methods — настраивает default-input-method для Emacs-IM
;;     (toggle по C-\) и пробрасывает XKB-layout в X-клиенты через
;;     exwm-xim. Эти два слоя НЕ пересекаются:
;;     - Emacs-IM (russian-computer) работает в Emacs-окнах, переключается
;;       по C-\ (toggle-input-method; см. emacs-keys.org).
;;     - XKB-раскладка (us,ru с grp:shifts_toggle из session-base.nix)
;;       работает в X-приложениях через exwm-xim.
;;
;; EXWM is provided via Nix (emacsPackages.exwm + emacsPackages.exwm-xim)
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

(defvar pro-exwm-autostart-apps
  '("nm-applet" "copyq" "udiskie --tray")
  "List of shell commands to autostart after EXWM session starts.
Each element is a string passed to `start-process-shell-command'.
Default starts common helpers: nm-applet, copyq, udiskie.")

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
    ;; Note: exwm-xim bridges the *system XKB layout* into X clients — it does
    ;; NOT expose Emacs' own `input-method' (russian-computer etc.) to X apps.
    ;; For Emacs-internal text input, set `default-input-method' below.
    (condition-case nil
        (require 'exwm-xim)
      (error nil))
    (when (fboundp 'exwm-xim-mode)
      (exwm-xim-mode 1))

    ;; Pick an Emacs-side input method so that `C-\' (toggle-input-method)
    ;; has something to toggle inside Emacs buffers.  We default to
    ;; `russian-computer' (the standard ЙЦУКЕН layout from leim) but only
    ;; if the user has not set one explicitly and the quail/cyrillic
    ;; package is available on load-path.  X clients are unaffected — see
    ;; the exwm-xim comment above for why the system XKB layout is what
    ;; X apps use, not this Emacs input method.
    (when (and (not (default-value 'default-input-method))
               (locate-library "quail/cyrillic"))
      (setq default-input-method 'russian-computer))

    ;; Start the window manager.  exwm-wm-mode is idempotent — calling it
    ;; when already enabled is a no-op.
    ;; When EXWM exits, kill Emacs — we ARE the session.
    (add-hook 'exwm-exit-hook #'kill-emacs)
    (exwm-wm-mode 1)
    (message "[pro-exwm] session started (workspaces: %d, systemtray: %s, xim: %s)"
             exwm-workspace-number
             (if (and (boundp 'exwm-systemtray-mode) exwm-systemtray-mode) "on" "off")
             (if (and (boundp 'exwm-xim-mode) exwm-xim-mode) "on" "off"))

    ;; Autostart small userland helpers (tray icons, clipboard daemon, udisks)
    ;; Start them only in a graphical session and only if the variable is set.
    (when (and (display-graphic-p) (boundp 'pro-exwm-autostart-apps))
      (dolist (cmd pro-exwm-autostart-apps)
        (let* ((name (format "pro-exwm-autostart-%s" (replace-regexp-in-string "[^A-Za-z0-9_-]" "-" cmd)))
               (existing (get-process name)))
          (unless existing
            (condition-case err
                (start-process-shell-command name nil cmd)
              (error (message "[pro-exwm] failed to autostart '%s': %s" cmd err)))))))
    ))

;; ── Init hooks ───────────────────────────────────────────────────────────
;;
;; `window-setup-hook' fires after Emacs has created the initial frame
;; but before it is displayed.  This is the canonical time to start
;; the window manager — the display is ready but the user hasn't seen
;; anything yet.

(defun pro-exwm--start-when-ready ()
  "Start EXWM as early as possible but only when environment is ready.

Tries several hooks to ensure EXWM starts before user-visible frames are
displayed while still having required packages and display variables set.
If the session isn't EXWM, this becomes a no-op.
"
  (when (pro-exwm--session-p)
    (pro-exwm-start-session)))

;; Try early hooks in order: early-window-setup (if present), window-setup,
;; and finally emacs-startup-hook as a fallback. This aims to start EXWM
;; as early as possible to reduce flicker.
(when (boundp 'early-window-setup-hook)
  (add-hook 'early-window-setup-hook #'pro-exwm--start-when-ready))
(add-hook 'window-setup-hook #'pro-exwm--start-when-ready)
(add-hook 'emacs-startup-hook #'pro-exwm--start-when-ready)

;; When pro-keys module finishes loading, re-apply global keys so any
;; keys registered via pro/register-module-keys (exwm layer) take effect.
(with-eval-after-load 'pro-keys
  (when (pro-exwm--session-p)
    (pro-exwm--apply-global-keys)))

(provide 'pro-exwm)

;;; pro-exwm.el ends here
