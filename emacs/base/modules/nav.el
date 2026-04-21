;;; nav.el --- поиск и навигация -*- lexical-binding: t; -*-

;; Модуль: nav.el — поиск и навигация.
;;
;; Назначение:
;; Задаёт единый набор команд и поведения для поиска по файлам, символам и
;; проектам. Оборачивает использование пакетов vertico/consult/orderless и
;; включает разумные fallbacks, если пакеты недоступны во время инициализации.

(when (or (pro--package-provided-p 'vertico) (pro-packages--maybe-install 'vertico t) (require 'vertico nil t))
  ;; vertico-mode может быть не загружен на этапе инициализации; поэтому
  ;; проверяем наличие определения функции и безопасно включаем режим.
  (when (fboundp 'vertico-mode)
    (vertico-mode 1)
    (setq vertico-cycle t))
  ;; Navigation keys inside Vertico
  (when (and (boundp 'vertico-map) (keymapp vertico-map))
    (define-key vertico-map (kbd "C-n") #'vertico-next)
    (define-key vertico-map (kbd "C-p") #'vertico-previous)
    (define-key vertico-map (kbd "C-j") #'vertico-next)
    (define-key vertico-map (kbd "C-k") #'vertico-previous)
    ;; Accept candidate with RET but keep original behavior in certain contexts
    (define-key vertico-map (kbd "RET") #'vertico-exit)))

(when (or (pro--package-provided-p 'orderless) (pro-packages--maybe-install 'orderless t) (require 'orderless nil t))
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil))

(when (or (pro--package-provided-p 'marginalia) (pro-packages--maybe-install 'marginalia t) (require 'marginalia nil t))
  ;; marginalia-mode может не иметь автозагрузки; включаем только при наличии.
  (when (fboundp 'marginalia-mode)
    (marginalia-mode 1)))

(when (or (pro--package-provided-p 'consult) (pro-packages--maybe-install 'consult t) (require 'consult nil t))
  (when (or (pro--package-provided-p 'consult-xref) (pro-packages--maybe-install 'consult-xref t) (require 'consult-xref nil t))
    ;; consult-xref может отсутствовать на этапе инициализации; присваиваем
    ;; хендлеры xref только при наличии consult-xref.
    (when (fboundp 'consult-xref)
      (setq xref-show-definitions-function #'consult-xref
            xref-show-xrefs-function #'consult-xref)))
  ;; Remap common commands to consult variants for a consistent UX
  (when (fboundp 'consult-find)
    (define-key global-map [remap find-file] #'consult-find))
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
    (setq consult-line-start-from-top t)))

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
