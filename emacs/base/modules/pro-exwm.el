;;; pro-exwm.el --- EXWM session glue for pro-nix -*- lexical-binding: t; -*-
;;
(require 'pro-compat)
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
;;     - XKB-раскладка (us,ru с grp:toggle из session-base.nix — Right Alt)
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

;; ── Input methods ────────────────────────────────────────────────────────
;;
;; Why this section is needed: in line-mode EXWM forwards every key from
;; an X window to Emacs first, *unless* the key is in `exwm-input-prefix-keys'
;; (or matches `exwm-input-global-keys').  In that case the key is consumed
;; by EXWM/Emacs and never reaches the X application.  Without
;; `C-\\' in `exwm-input-prefix-keys' the key falls through to the X app
;; (Firefox uses it for "close tab", many other apps use it for "quit"),
;; and `toggle-input-method' therefore cannot be invoked from inside
;; an X window.  See the official exwm-xim.el commentary:
;;
;;   A keybinding for `toggle-input-method' is probably required to turn
;;   on & off an input method (default to `default-input-method').  It's
;;   bound to 'C-\\' by default and can be made reachable when working
;;   with X windows:
;;
;;      (push ?\\C-\\\\ exwm-input-prefix-keys)
;;
;; We do the same plus a few related keys (C-\\, C-^, C-`) so the
;; user can also use isearch-style switching if desired.
(defvar pro-exwm-im-prefix-keys
  '(?\C-\\ ?\C-^ ?\C-`)
  "EXWM prefix keys forwarded to Emacs so IM-related bindings work in X apps.
`C-\\' is the default `toggle-input-method' binding.
`C-^' and `C-`' are alternatives if the user prefers a different switch.")

(defun pro-exwm--install-im-prefix-keys ()
  "Add `pro-exwm-im-prefix-keys' to `exwm-input-prefix-keys'."
  (when (boundp 'exwm-input-prefix-keys)
    (dolist (k pro-exwm-im-prefix-keys)
      (unless (memq k exwm-input-prefix-keys)
        (push k exwm-input-prefix-keys)))))

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
  - Регистрирует C-\\ в exwm-input-prefix-keys (чтобы toggle-input-method
    работал в X-окнах)
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

    ;; Make `toggle-input-method' reachable from X windows BEFORE
    ;; exwm-wm-mode init (the prefix-keys list is consumed once).
    (pro-exwm--install-im-prefix-keys)

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

    ;; Start the initial frame in fullscreen so EXWM doesn't show a small
    ;; window on first paint.  Works even when xrdb didn't apply the
    ;; `Emacs.fullscreen: maximized' line (eg. exwm-session started before
    ;; xrdb ran).
    (when (display-graphic-p)
      (set-frame-parameter nil 'fullscreen 'fullscreen))

    ;; Install the urxvt-sidebar management hook (idempotent).
    (pro-exwm--install-urxvt-sidebar-hook)

    (message "[pro-exwm] session started (workspaces: %d, systemtray: %s, xim: %s)"
             exwm-workspace-number
             (if (and (boundp 'exwm-systemtray-mode) exwm-systemtray-mode) "on" "off")
             (if (and (boundp 'exwm-xim-mode) exwm-xim-mode) "on" "off"))))

;; ── Urxvt bottom-sidebar toggle ────────────────────────────────────────────
;;
;; Spawns `urxvt' as a child X window and, after EXWM manages it, uses
;; `xdotool' to position it as a sidebar at the bottom of the screen.  A
;; second invocation closes the X client and clears the state.
;;
;; Why xdotool:  EXWM manages X windows itself and does not expose a
;; built-in "set position/size" function for non-floating windows.  A
;; shell-out to xdotool after `exwm-manage-finish-hook' is the most
;; reliable and least invasive way to override the WM's tiling decision.
;;
;; Naming:  urxvt is invoked with `-name pro-urxvt-sidebar -title
;; pro-urxvt-sidebar' so we can find the window unambiguously even if the
;; user has other urxvt instances running.

(defvar pro-exwm-urxvt--id nil
  "X11 window id of the toggled urxvt sidebar, or nil if not running.")

(defvar pro-exwm-urxvt--program "urxvt"
  "Program used by `pro/exwm-urxvt-toggle' to spawn the urxvt sidebar.")

(defcustom pro-exwm-urxvt--height-fraction 0.40
  "Height of the urxvt bottom sidebar as a fraction of the display height.
0.40 ⇒ sidebar занимает 40% высоты экрана снизу.  Минимум — 200px."
  :type 'float :group 'pro-exwm)

(defun pro-exwm-urxvt--read-display ()
  "Return (W H) of the current X display root window, or sensible defaults."
  (let ((w (ignore-errors (x-display-pixel-width)))
        (h (ignore-errors (x-display-pixel-height))))
    (list (or w 1920) (or h 1080))))

(defun pro-exwm-urxvt--run-xdotool (&rest args)
  "Run xdotool with ARGS.  Returns non-nil on exit-code 0."
  (when-let ((bin (executable-find "xdotool")))
    (zerop (apply #'call-process bin nil nil nil args))))

(defun pro-exwm-urxvt--find-by-name (name)
  "Return the integer X window id of the X window whose name matches NAME."
  (when-let ((bin (executable-find "xdotool")))
    (with-temp-buffer
      (when (zerop (call-process bin nil t nil "search" "--name" name ""))
        (goto-char (point-min))
        (skip-syntax-forward " ")
        (when (looking-at "[0-9a-fA-F]+")
          (string-to-number (match-string 0) 16))))))

(defun pro-exwm-urxvt--position (id)
  "Move/resize the X window ID to occupy the bottom sidebar slot."
  (when (and id (integerp id))
    (let* ((geom (pro-exwm-urxvt--read-display))
           (w (car geom))
           (h (cadr geom))
           (sidebar-h (max 200 (floor (* h pro-exwm-urxvt--height-fraction))))
           (sidebar-y (max 0 (- h sidebar-h)))
           (hex (format "0x%x" id)))
      (pro-exwm-urxvt--run-xdotool "windowmove" hex "0" (number-to-string sidebar-y))
      (pro-exwm-urxvt--run-xdotool "windowsize" hex (number-to-string w) (number-to-string sidebar-h))
      (pro-exwm-urxvt--run-xdotool "windowraise" hex))))

(defun pro-exwm-urxvt--on-manage ()
  "Hook: reposition the urxvt sidebar after EXWM has finished managing it."
  (when (and (boundp 'exwm-class-name) (string= exwm-class-name "URxvt")
             (boundp 'exwm-title) (string= exwm-title "pro-urxvt-sidebar")
             (boundp 'exwm-id) (integerp exwm-id))
    (setq pro-exwm-urxvt--id exwm-id)
    ;; Defer the move/resize a tick: the window may not be mapped yet
    ;; when `exwm-manage-finish-hook' fires.
    (run-with-timer 0.05 nil
                    (lambda () (pro-exwm-urxvt--position pro-exwm-urxvt--id)))))

(defun pro-exwm--install-urxvt-sidebar-hook ()
  "Idempotently install the urxvt sidebar management hook."
  (when (and (boundp 'exwm-manage-finish-hook)
             (not (memq #'pro-exwm-urxvt--on-manage exwm-manage-finish-hook)))
    (add-hook 'exwm-manage-finish-hook #'pro-exwm-urxvt--on-manage)))

(defun pro/exwm-urxvt-toggle ()
  "Toggle the urxvt bottom sidebar in EXWM.
First call: spawns `urxvt' (`-name pro-urxvt-sidebar -title pro-urxvt-sidebar')
and positions it as a 40% bottom sidebar.
Second call: closes the running X client and clears state.
No-op outside EXWM."
  (interactive)
  (unless (and (fboundp 'exwm-wm-mode) exwm-wm-mode)
    (user-error "pro/exwm-urxvt-toggle: EXWM is not running"))
  (let* ((id pro-exwm-urxvt--id)
         (hex (and id (format "0x%x" id)))
         (still-there (and hex
                           (pro-exwm-urxvt--run-xdotool "getwindowname" hex))))
    (if still-there
        (progn
          (pro-exwm-urxvt--run-xdotool "windowclose" hex)
          (setq pro-exwm-urxvt--id nil)
          (message "[pro-exwm] urxvt sidebar closed"))
      (setq pro-exwm-urxvt--id nil)
      (start-process-shell-command
       "pro-urxvt-sidebar" nil
       (concat pro-exwm-urxvt--program
               " -name pro-urxvt-sidebar -title pro-urxvt-sidebar"))
      (message "[pro-exwm] urxvt sidebar spawned"))))

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
  (pro-compat--add-hook-once 'early-window-setup-hook #'pro-exwm--start-when-ready))
(pro-compat--add-hook-once 'window-setup-hook #'pro-exwm--start-when-ready)
(pro-compat--add-hook-once 'emacs-startup-hook #'pro-exwm--start-when-ready)

;; When pro-keys module finishes loading, re-apply global keys so any
;; keys registered via pro/register-module-keys (exwm layer) take effect.
(with-eval-after-load 'pro-keys
  (when (pro-exwm--session-p)
    (pro-exwm--apply-global-keys)))

;; Re-apply IM prefix keys after EXWM is loaded.  This makes sure the
;; prefix-keys are present even if pro-exwm is loaded before exwm, and
;; also covers a soft reload (C-x M-c).
(with-eval-after-load 'exwm
  (when (pro-exwm--session-p)
    (pro-exwm--install-im-prefix-keys)))

(provide 'pro-exwm)

;;; pro-exwm.el ends here
