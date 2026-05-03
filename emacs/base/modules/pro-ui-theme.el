;;; pro-ui-theme.el --- Theme helpers for pro UI -*- lexical-binding: t; -*-
;; Назначение: безопасная ранняя загрузка тем и механизм hook'ов после load-theme.
;;
;; Контракт:
;; - pro-ui-load-default-theme-if-set — безопасна к вызову из early-init.
;; - pro-ui-after-load-theme-hook — hook, вызываемый после load-theme.
;;
;; Proof: headless ERT и manual smoke checks via ./scripts/emacs-pro-wrapper.sh
;; Last reviewed: 2026-05-03

(defgroup pro-ui-theme nil
  "Theme helpers for pro UI"
  :group 'pro-ui)

(defcustom pro-ui-default-theme 'tao-yang
  "Symbolic name of theme to try to load early (opt-in).
  If nil, no theme is loaded by pro-ui early. Set to e.g. 'tao-yang to
  attempt early load when running in GUI. Loading is guarded to avoid
  errors when the theme package isn't present."
  :type '(choice (const :tag "none" nil) symbol)
  :group 'pro-ui-theme)

(defvar pro-ui-after-load-theme-hook nil
  "Hook run after `load-theme' via advice.")

(defun pro-ui--run-after-load-theme-hook (&rest _args)
  "Run `pro-ui-after-load-theme-hook'." 
  (run-hooks 'pro-ui-after-load-theme-hook))

;; Attach advice to load-theme so modules can reset caches
(advice-add 'load-theme :after #'pro-ui--run-after-load-theme-hook)

(defun pro-ui-load-default-theme-if-set ()
  "Load `pro-ui-default-theme' early if it is set and available.
This function is safe to call in early-init; it will not error if
the theme isn't present." 
  (when (and pro-ui-default-theme (display-graphic-p))
    (condition-case _err
        (when (locate-library (format "%s-theme" pro-ui-default-theme))
          (load-theme pro-ui-default-theme t))
      (error (message "[pro-ui] default theme %s not available" pro-ui-default-theme)))))

(provide 'pro-ui-theme)
