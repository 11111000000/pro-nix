;;; nav.el --- поиск и навигация -*- lexical-binding: t; -*-

;; Модуль: nav.el — поиск и навигация.
;;
;; Назначение:
;; Задаёт единый набор команд и поведения для поиска по файлам, символам и
;; проектам. Оборачивает использование пакетов vertico/consult/orderless и
;; включает разумные fallbacks, если пакеты недоступны во время инициализации.

;; Utility
(require 'cl-lib)

(when (or (pro--package-provided-p 'vertico) (pro-packages--maybe-install 'vertico t) (require 'vertico nil t))
  ;; vertico-mode может быть не загружен на этапе инициализации; поэтому
  ;; проверяем наличие определения функции и безопасно включаем режим.
  (when (fboundp 'vertico-mode)
    (vertico-mode 1)
    (setq vertico-cycle t))
  ;; Install navigation keys after vertico is loaded to avoid timing issues.
  (with-eval-after-load 'vertico
    (when (and (boundp 'vertico-map) (keymapp vertico-map))
      (define-key vertico-map (kbd "C-n") #'vertico-next)
      (define-key vertico-map (kbd "C-p") #'vertico-previous)
      (define-key vertico-map (kbd "C-j") #'vertico-next)
      (define-key vertico-map (kbd "C-k") #'vertico-previous)
      ;; Make TAB cycle candidates (and Shift-TAB go back). In terminals TAB
      ;; is often `C-i', so bind that too — this makes TAB/C-i behave like C-n.
      (define-key vertico-map (kbd "TAB") #'vertico-next)
      (define-key vertico-map (kbd "<backtab>") #'vertico-previous)
      (define-key vertico-map (kbd "C-i") #'vertico-next)
      ;; Accept candidate with RET but keep original behavior in certain contexts
      (define-key vertico-map (kbd "RET") #'vertico-exit))))

;; Configure Orderless for fuzzy matching only after the style is registered.
;; Setting `completion-styles' to include a style name that is not registered
;; triggers errors (see "Invalid completion style orderless"). Therefore we
;; defer changing `completion-styles' until orderless is actually available.
(when (or (and (require 'orderless nil t))
          (and (fboundp 'pro-packages--maybe-install)
               (pro-packages--maybe-install 'orderless t)
               (require 'orderless nil t)))
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil))

(when (or (pro--package-provided-p 'marginalia) (pro-packages--maybe-install 'marginalia t) (require 'marginalia nil t))
  ;; marginalia-mode может не иметь автозагрузки; включаем только при наличии.
  (when (fboundp 'marginalia-mode)
    (marginalia-mode 1)))

;; Defer consult-specific remaps and integration until consult is actually loaded
(with-eval-after-load 'consult
  ;; consult-xref handlers
  (when (require 'consult-xref nil t)
    (when (fboundp 'consult-xref)
      (setq xref-show-definitions-function #'consult-xref
            xref-show-xrefs-function #'consult-xref)))

  ;; Remap common commands to consult variants for a consistent UX
  (when (fboundp 'consult-find)
    (define-key global-map [remap find-file] #'pro/consult-find))
  (when (fboundp 'consult-buffer)
    (define-key global-map [remap switch-to-buffer] #'consult-buffer))
  (when (fboundp 'consult-goto-line)
    (define-key global-map [remap goto-line] #'consult-goto-line))
  (when (fboundp 'consult-imenu)
    (define-key global-map [remap imenu] #'consult-imenu))
  (when (fboundp 'consult-bookmark)
    (define-key global-map [remap bookmark-jump] #'consult-bookmark))
  (when (fboundp 'consult-yank-pop)
    (define-key global-map [remap yank-pop] #'consult-yank-pop))
  (when (fboundp 'consult-complex-command)
    (define-key global-map [remap repeat-complex-command] #'consult-complex-command))

  ;; Helpful consult defaults
  (when (fboundp 'consult-line)
    (setq consult-preview-key "M-.")
    (setq consult-line-start-from-top t))

  ;; Embark integration and recommended bindings
  (when (require 'embark nil t)
    (when (fboundp 'embark-act)
      (global-set-key (kbd "C-.") #'embark-act)
      (global-set-key (kbd "C-;") #'embark-dwim)))

  ;; Load and enable embark-consult integration if present
  (when (require 'embark-consult nil t)
    ;; embark-consult auto-registers; nothing else required here
    )

  ;; Useful consult extensions and tweaks (lazy, non-fatal requires)
  ;; consult-dash: initialize with symbol at point for convenience
  (when (require 'consult-dash nil t)
    (when (fboundp 'consult-customize)
      (consult-customize consult-dash :initial (thing-at-point 'symbol))))

  ;; consult-yasnippet: allow searching snippets via consult UI when available
  (when (require 'consult-yasnippet nil t)
    ;; no extra config required; binding is provided in completion-keys module
    )

  ;; consult-eglot: bind a convenient key in eglot-mode if available
  (when (require 'consult-eglot nil t)
    (with-eval-after-load 'eglot
      (when (boundp 'eglot-mode-map)
        (define-key eglot-mode-map (kbd "C-c C-.") #'consult-eglot-symbols))))

  ;; Tweak consult-buffer sources to avoid noisy "Select Project" entries
  (when (and (boundp 'consult-buffer-sources) (fboundp 'cl-remove))
    (setq consult-buffer-sources
          (cl-remove 'consult--source-project-buffer consult-buffer-sources :test #'eq)))
  ;; Provide helper functions (small and defensive); load only if consult is present
  (when (require 'consult-helpers nil t)
    ;; remap consult-buffer to our helper which augments behavior for EXWM/tab-bar
    (when (fboundp 'pro/consult-buffer)
      (define-key global-map [remap switch-to-buffer] #'pro/consult-buffer)))
  )

(defun pro-nav-search-project ()
  "Искать в текущем проекте, если доступен project root."
  (interactive)
  (if (or (pro--package-provided-p 'consult) (require 'consult nil t))
      (if (fboundp 'pro-project-root)
          (consult-ripgrep (or (pro-project-root) default-directory))
        (consult-ripgrep default-directory))
    (pro-compat--notify-once "consult" "consult missing — pro-nav-search-project fallback to grep")
    (let ((default-directory (or (and (fboundp 'pro-project-root) (pro-project-root)) default-directory)))
      (call-interactively #'grep))))

(defun pro-nav-open-line ()
  "Открыть строковый поиск."
  (interactive)
  (if (or (pro--package-provided-p 'consult) (require 'consult nil t))
      (consult-line)
    (pro-compat--notify-once "consult" "consult missing — pro-nav-open-line fallback to isearch")
    (call-interactively #'isearch-forward)))

(provide 'nav)
