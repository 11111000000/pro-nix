;;; pro-ui-theme.el --- Theme helpers for pro UI -*- lexical-binding: t; -*-
;; Назначение: безопасная ранняя загрузка тем и механизм hook'ов после load-theme.
;;
;; Контракт:
;; - pro-ui-apply-theme — публичная точка применения темы из pro-ui-default-theme.
;; - pro-ui-after-load-theme-hook — hook, вызываемый после load-theme.
;;
;; Proof: headless ERT и manual smoke checks via ./scripts/emacs-pro-wrapper.sh
;; Last reviewed: 2026-05-03

(require 'pro-compat)

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
(pro-compat--advice-add-once 'load-theme :after #'pro-ui--run-after-load-theme-hook)

;; Built-in post-load-theme hook: чистит nil-атрибуты, оставленные
;; темами с неполной палитрой (tao-theme и т.п.). Запускается
;; автоматически после load-theme, но модули могут его дополнить.
(add-hook 'pro-ui-after-load-theme-hook #'pro-ui--sanitize-nil-face-attributes)

;; Re-sanitize on package load: catches downstream packages
;; (treemacs, magit, ...) whose defface reads face-background of a
;; `unspecified' attribute and ends up with `:foreground nil'. The
;; warning is printed once at the defface-evaluation time and Emacs
;; immediately rewrites `nil' → `unspecified', so this pass is a
;; belt-and-suspenders: it normalizes any residual nil that survived
;; for whatever reason. Cost is O(F) per package load; deferred to
;; `after-load-functions' to keep startup latency intact (Emacs 28+).
(when (boundp 'after-load-functions)
  (add-hook 'after-load-functions #'pro-ui--sanitize-nil-face-attributes 100))

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
        (error (message "[pro-ui] failed to apply default theme %s: %S" theme-name _err))))
    ;; tao-theme (и другие palette-based темы) при неполной палитре
    ;; подставляют `nil' в `:foreground'/`:background' — Emacs ругается
    ;; "Warning: setting attribute ':foreground' of face ... nil value
    ;; is invalid, use 'unspecified' instead." Чистим post-load.
    (pro-ui--sanitize-nil-face-attributes)))

(defun pro-ui--sanitize-nil-face-attributes (&optional _feature)
  "Заменить `:foreground nil'/`:background nil' на `unspecified' во всех face'ах.

Защищает от warning'ов типа:

  Warning: setting attribute \\=':foreground of face
  \\='treemacs-fringe-indicator-face: nil value is invalid,
  use \\='unspecified instead.

Источники `nil' там, где Emacs ждёт `unspecified':
  * Темы с неполной палитрой (tao-theme при отсутствующих
    color-13/14) — `tao-theme--sanitize-faces' фиксит это в самом
    submodule сразу после custom-theme-set-faces. Этот sanitizer
    остаётся страховкой для тем, которые не санитизируют себя сами.
  * Пакеты, читающие face значения через `face-background'/`face-
    foreground' (которые возвращают литеральный `nil', а не символ
    `unspecified', для unspecified атрибутов) и вставляющие `nil' в
    свои defface-формы. Treemacs — главный пример
    (treemacs-fringe-indicator-face). Сам warning напечатается
    один раз при загрузке такого пакета (defface оценивается во
    время load), и Emacs сразу конвертирует `nil' → `unspecified'
    (поэтому второй заход sanitizer-а видит уже unspecified и
    оставляет в покое).

Идемпотентно: прогонять можно после каждого load-theme /
disable-theme / package load. Стоимость — O(F) проходов
по `face-list', где F — количество face'ов (несколько сотен).

_OPTIONAL _FEATURE is the absolute file name passed by
`after-load-functions' (the post-load hook that registers this
sanitizer). It is unused -- the walk is the same regardless of
which feature triggered the load -- but accepting the argument
prevents `wrong-number-of-arguments' errors at load time."

  (dolist (face (face-list))
    (condition-case nil
        (let ((fg (face-attribute face :foreground))
              (bg (face-attribute face :background)))
          ;; Only the LITERAL `nil' (not `unspecified' and not a
          ;; color string) means we need to rewrite. `set-face-attribute
          ;; nil :foreground nil' is a no-op in modern Emacs, so the
          ;; rewrite is the only way to recover.
          (when (eq fg nil) (set-face-attribute face nil :foreground 'unspecified))
          (when (eq bg nil) (set-face-attribute face nil :background 'unspecified)))
      (error nil))))

(provide 'pro-ui-theme)
