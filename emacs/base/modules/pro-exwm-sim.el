;;; pro-exwm-sim.el --- EXWM input simulation helpers (pro-nix implementation) -*- lexical-binding: t; -*-
;;
;; EXWM simulation keys translate Emacs-style key sequences (typed in line-mode)
;; into X11 keystrokes forwarded to the application.  This is how you get
;; Emacs keybindings like C-n/C-p/C-f/C-b/C-y/C-w to work inside apps.
;;
;; EXWM has TWO distinct mechanisms:
;;   1. `exwm-input-global-keys'  — global Emacs commands that intercept keys
;;      before they reach the app (e.g. s-w to switch workspace).
;;   2. `exwm-input-simulation-keys' — keys typed in line-mode that get
;;      translated and sent to the X window as if the app received them.
;;
;; This module implements #2 — the "Emacs keys in any app" layer.
;;
;; NOTE: Unlike the previous version, the guard is DYNAMIC — simulation keys
;; are applied from `pro-exwm-start-session' (BEFORE `exwm-wm-mode'), not at
;; module load time.  This is critical because `XDG_CURRENT_DESKTOP' may not
;; be set yet when modules are loaded during Emacs startup from GDM.
;; `exwm-init-hook' fires too late — after `exwm-input--init' reads
;; `exwm-input-simulation-keys'.

(defvar pro/exwm-default-simulation-keys
  '(([?\C-b] . left)       ; C-b → Left arrow
    ([?\M-b] . C-left)     ; M-b → Ctrl+Left (word back)
    ([?\C-f] . right)      ; C-f → Right arrow
    ([?\M-f] . C-right)    ; M-f → Ctrl+Right (word forward)
    ([?\C-p] . up)         ; C-p → Up arrow
    ([?\C-n] . down)       ; C-n → Down arrow
    ([?\C-a] . home)       ; C-a → Home
    ([?\C-e] . end)        ; C-e → End
    ([?\M-v] . prior)      ; M-v → Page Up
    ([?\C-v] . next)       ; C-v → Page Down
    ([?\C-d] . ?\C-x)      ; C-d → C-x (careful: delete-forward-char isn't universal in apps)
    ([?\M-d] . (C-S-right delete)) ; M-d → Ctrl+Shift+Right then Delete (kill-word)
    ([?\M-y] . ?\C-c)      ; M-y → C-c (copy in most GUI apps)
    ([?\M-w] . ?\C-c)      ; M-w → C-c (copy)
    ([?\C-y] . ?\C-v)      ; C-y → C-v (paste)
    ([?\C-s] . ?\C-f)      ; C-s → C-f (find in most apps)
    ([?\C-r] . ?\C-f)      ; C-r → C-f (isearch-backward → find, debatable but convenient)
    ([?\C-k] . (S-end ?\C-x)) ; C-k → Shift+End, C-x (kill-line → select-to-end + cut)
    ([?\C-w] . ?\C-x)      ; C-w → C-x (cut)
    ([?\M-<] . C-home)     ; M-< → Ctrl+Home
    ([?\M->] . C-end))     ; M-> → Ctrl+End
  "Default simulation keys mapping Emacs keys to X11 keys.

Each entry is (ORIGINAL . SIMULATED), where both are key sequences.
ORIGINAL is what you type in line-mode; SIMULATED is what gets sent
to the X window.

Set via `exwm-input-simulation-keys' — the official EXWM customization
variable.  Applied when `exwm-input--init' runs.")

;; ── Dynamic guard — apply simulation keys when EXWM starts ───────────────
;;
;; Simulation keys MUST be set BEFORE `exwm-wm-mode' activates because
;; `exwm--init' → `exwm-input--init' reads `exwm-input-simulation-keys'
;; once.  `exwm-init-hook' fires after input-init, which is too late.
;;
;; The canonical call site is `pro-exwm-start-session' in pro-exwm.el —
;; it calls `pro/exwm-apply-default-simulation-keys' before `exwm-wm-mode'.

(defvar pro-exwm-sim--applied nil
  "Non-nil when simulation keys have been applied in this session.")

(defun pro/exwm-apply-default-simulation-keys ()
  "Apply `pro/exwm-default-simulation-keys' to `exwm-input-simulation-keys'.

Must be called BEFORE `exwm-input--init', e.g. in your early EXWM
config.  EXWM reads `exwm-input-simulation-keys' once during init;
changing it later has no effect.

Idempotent across multiple calls — applies defaults only once per session."
  (interactive)
  (when (and (boundp 'exwm-input-simulation-keys)
             (not pro-exwm-sim--applied))
    (setq exwm-input-simulation-keys
          (append exwm-input-simulation-keys
                  pro/exwm-default-simulation-keys))
    (setq pro-exwm-sim--applied t)
    (message "[pro-exwm-sim] applied %d simulation keys"
             (length pro/exwm-default-simulation-keys))))

(provide 'pro-exwm-sim)

;;; pro-exwm-sim.el ends here