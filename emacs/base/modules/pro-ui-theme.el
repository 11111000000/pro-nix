;;; pro-ui-theme.el --- Theme helpers for pro UI -*- lexical-binding: t; -*-
;; Назначение: безопасная ранняя загрузка тем и механизм hook'ов после load-theme.
;;
;; Контракт:
;; - pro-ui-apply-theme — публичная точка применения темы из pro-ui-default-theme.
;; - pro-ui-after-load-theme-hook — hook, вызываемый после load-theme.
;;
;; Proof: headless ERT и manual smoke checks via ./scripts/emacs-pro-wrapper.sh
;; Last reviewed: 2026-05-03

(defgroup pro-ui-theme nil
  "Theme helpers for pro UI"
  :group 'pro-ui)

(defcustom pro-ui-default-theme 'tao-yang
  "Symbolic name of theme to load by default at startup.
Set to nil to disable automatic theme loading. Loading is guarded
so missing packages don't error out (a message is shown instead).
Works in both GUI and TTY frames."
  :type '(choice (const :tag "none" nil) symbol)
  :group 'pro-ui-theme)

(defvar pro-ui-after-load-theme-hook nil
  "Hook run after `load-theme' via advice.")

(defun pro-ui--run-after-load-theme-hook (&rest _args)
  "Run `pro-ui-after-load-theme-hook'."
  (run-hooks 'pro-ui-after-load-theme-hook))

;; Attach advice to load-theme so modules can reset caches
(advice-add 'load-theme :after #'pro-ui--run-after-load-theme-hook)

(defun pro-ui-apply-theme ()
  "Apply `pro-ui-default-theme' if it is set and the package is available.
Safe to call at startup and on `pro/reload-config': no error is raised
when the theme package is missing. Works in both GUI and TTY frames.

Implementation note: `load-theme' searches `custom-theme-load-path',
not `load-path'. We locate the theme file via `locate-library' and
register its directory on both lists so the theme and any sibling
files it `require's (e.g. tao-yang-theme requires tao-theme) can be
found."
  (when pro-ui-default-theme
    (let* ((theme-name (symbol-name pro-ui-default-theme))
           (lib (format "%s-theme" theme-name))
           (file (locate-library lib)))
      (condition-case _err
          (cond
           ((null file)
            (message "[pro-ui] default theme %s not available on load-path" theme-name))
           (t
            (let ((dir (file-name-directory file)))
              (unless (member dir load-path)
                (push dir load-path))
              (unless (member dir custom-theme-load-path)
                (push dir custom-theme-load-path)))
            (unless (custom-theme-p pro-ui-default-theme)
              (load-theme pro-ui-default-theme t))))
        (error (message "[pro-ui] failed to apply default theme %s: %S" theme-name _err))))))

(provide 'pro-ui-theme)
