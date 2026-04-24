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


;; Universal minibuffer TAB behaviour: cycle candidates where appropriate.
(defun pro/minibuffer-tab ()
  "TAB behaviour in minibuffer: cycle Vertico/MCT candidates if active, else fallback to minibuffer-complete." 
  (interactive)
  (cond
   ;; Vertico active: go to next candidate
   ((and (boundp 'vertico--input) vertico--input (fboundp 'vertico-next))
    (vertico-next))
   ;; MCT (minibuffer completion at point) support if present
   ((and (boundp 'mct--active) mct--active (fboundp 'mct-next))
    (mct-next))
   ;; Fallback: normal minibuffer completion
   (t
    (minibuffer-complete))))

(defun pro/minibuffer-backtab ()
  "Shift-TAB behaviour in minibuffer: previous candidate or minibuffer-complete-backward." 
  (interactive)
  (cond
   ((and (boundp 'vertico--input) vertico--input (fboundp 'vertico-previous))
    (vertico-previous))
   ((and (boundp 'mct--active) mct--active (fboundp 'mct-previous))
    (mct-previous))
   (t
    (when (fboundp 'minibuffer-complete-backward)
      (minibuffer-complete-backward)))))

;; Install TAB/C-i/<backtab> into common minibuffer maps so the behavior is
;; uniform across C-x C-f, M-x and other minibuffer-driven commands.
(dolist (map '(minibuffer-local-map
               minibuffer-local-ns-map
               minibuffer-local-completion-map
               minibuffer-local-must-match-map))
  (when (boundp (intern (symbol-name map)))
    (let ((m (symbol-value (intern (symbol-name map)))))
      (when (keymapp m)
        (define-key m (kbd "TAB") #'pro/minibuffer-tab)
        (define-key m (kbd "C-i") #'pro/minibuffer-tab)
        (define-key m (kbd "<backtab>") #'pro/minibuffer-backtab)))))

;; Navigation bindings in minibuffer: C-n / C-p should move between candidates
(defun pro/minibuffer-next ()
  "Move to next candidate in minibuffer completion UIs (Vertico/MCT/other)."
  (interactive)
  (cond
   ((and (boundp 'vertico--input) vertico--input (fboundp 'vertico-next))
    (vertico-next))
   ((and (boundp 'mct--active) mct--active (fboundp 'mct-next))
    (mct-next))
   ;; In some modes completion-list-mode may be used; use next-line there.
   ((and (derived-mode-p 'completion-list-mode) (fboundp 'next-line))
    (next-line 1))
   (t
    ;; fallback: try minibuffer-complete which might update candidates
    (minibuffer-complete))))

(defun pro/minibuffer-previous ()
  "Move to previous candidate in minibuffer completion UIs (Vertico/MCT/other)."
  (interactive)
  (cond
   ((and (boundp 'vertico--input) vertico--input (fboundp 'vertico-previous))
    (vertico-previous))
   ((and (boundp 'mct--active) mct--active (fboundp 'mct-previous))
    (mct-previous))
   ((and (derived-mode-p 'completion-list-mode) (fboundp 'previous-line))
    (previous-line 1))
   (t
    (when (fboundp 'minibuffer-complete-backward)
      (minibuffer-complete-backward)))))

(dolist (map '(minibuffer-local-map
               minibuffer-local-ns-map
               minibuffer-local-completion-map
               minibuffer-local-must-match-map))
  (when (boundp (intern (symbol-name map)))
    (let ((m (symbol-value (intern (symbol-name map)))))
      (when (keymapp m)
        (define-key m (kbd "C-n") #'pro/minibuffer-next)
        (define-key m (kbd "C-p") #'pro/minibuffer-previous)
        ;; Also accept C-j/C-k as navigation aliases (common preference)
        (define-key m (kbd "C-j") #'pro/minibuffer-next)
        (define-key m (kbd "C-k") #'pro/minibuffer-previous)))))

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

;; Defer consult-specific integration until consult is actually loaded.
;; ВАЖНО: Глобальные клавиши не назначаем здесь — они живут в emacs-keys.org
;; и применяются модулем keys.el. Здесь только настройки поведения/интеграции.
(with-eval-after-load 'consult
  ;; consult-xref handlers
  (when (require 'consult-xref nil t)
    (when (fboundp 'consult-xref)
      (setq xref-show-definitions-function #'consult-xref
            xref-show-xrefs-function #'consult-xref)))

  ;; Helpful consult defaults
  (when (fboundp 'consult-line)
    (setq consult-preview-key "M-.")
    (setq consult-line-start-from-top t))

  ;; Embark integration (без глобальных клавиш; бинды — через emacs-keys.org)
  (when (require 'embark nil t)
    (ignore (fboundp 'embark-act)))

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
  ;; Provide helper functions (small and defensive); no global remaps here.
  (require 'consult-helpers nil t)
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
