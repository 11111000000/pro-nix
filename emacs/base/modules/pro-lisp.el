;;; lisp.el --- Lisp и структурное редактирование -*- lexical-binding: t; -*-

(require 'pro-compat)
(require 'pro-reload)

;; Этот модуль усиливает главную конфигурационную среду: Emacs Lisp.

(show-paren-mode 1)
(setq show-paren-delay 0.1)

(defun pro-lisp-setup ()
  "Подготовить Lisp-редактирование как основную среду разработки конфига."
  (setq-local indent-tabs-mode nil)
  (setq-local fill-column 88))

(defun pro-lisp-reload-buffer ()
  "Reload current Emacs-Lisp buffer: re-run all top-level forms.

Работает только в `emacs-lisp-mode'. В `lisp-interaction-mode' (например,
*scratch*) не привязывается — там стандартное `C-c C-c' =
`eval-print-last-sexp' остаётся.

Использует `pro/reload-file' с путём файла буфера, что гарантирует
реальное перевыполнение top-level-форм (`defvar', `defcustom',
`defun', `add-hook', etc.) в текущей сессии Emacs, без рестарта."
  (interactive)
  (if (not (derived-mode-p 'emacs-lisp-mode))
      (user-error "pro/lisp-reload-buffer: not in emacs-lisp-mode")
    (let ((file buffer-file-name))
      (if (not file)
          (user-error "pro/lisp-reload-buffer: buffer is not visiting a file")
        (when (buffer-modified-p)
          (save-buffer))
        (pro/reload-file file)))))

;; Back-compat alias — старая команда по-прежнему работает, но через
;; `eval-buffer' (читает буфер, без выброса load-history). Для реального
;; reload-file используйте `pro/lisp-reload-buffer' / `pro/reload-file'.
(defalias 'pro-lisp-eval-buffer #'eval-buffer)

(when (or (pro--package-provided-p 'rainbow-delimiters) (pro-packages--maybe-install 'rainbow-delimiters t) (require 'rainbow-delimiters nil t))
  ;; Guard mode function in case package is partially loaded.
  (when (fboundp 'rainbow-delimiters-mode)
    (pro-compat--add-hook-once 'emacs-lisp-mode-hook #'rainbow-delimiters-mode)
    (pro-compat--add-hook-once 'lisp-interaction-mode-hook #'rainbow-delimiters-mode)))

(pro-compat--add-hook-once 'emacs-lisp-mode-hook #'pro-lisp-setup)
(pro-compat--add-hook-once 'lisp-interaction-mode-hook #'pro-lisp-setup)

;; C-c C-c в emacs-lisp-mode → реальный reload файла (re-run top-level).
;; В lisp-interaction-mode (*scratch*) не трогаем — там дефолтный
;; `eval-print-last-sexp' остаётся.
(pro-compat--add-hook-once 'emacs-lisp-mode-hook
  (lambda ()
    (local-set-key (kbd "C-c C-c") #'pro-lisp-reload-buffer)))

(provide 'pro-lisp)
