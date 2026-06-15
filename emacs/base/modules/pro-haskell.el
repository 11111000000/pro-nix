;;; pro-haskell.el --- Haskell editing, REPL, LSP, format, lint -*- lexical-binding: t; -*-

;; Назначение: полноценная поддержка Haskell в Emacs.
;;
;; Контракт:
;; - Открывает .hs/.lhs/.cabal/.stack.yaml в правильных major-mode.
;; - Подключает haskell-mode + haskell-indentation + haskell-font-lock +
;;   haskell-doc-mode (если пакет предоставлен Nix или установлен вручную).
;; - При наличии eglot запускает haskell-language-server-wrapper для .hs.
;; - Хелперы: load buffer/module in REPL, switch to REPL, format (fourmolu),
;;   lint (hlint), browse Haddock.
;; - Пакеты `haskell-mode' и `haskell-snippets' объявлены в
;;   emacs/core.nix providedPackages. При их отсутствии модуль тихо деградирует
;;   до plain `fundamental-mode' (аналогично поведению pro-python при
;;   отсутствии eglot).
;;
;; Proof: headless ERT (emacs/base/tests/test-haskell.el) и ручной smoke
;; в `M-x haskell-mode' в .hs-файле + проверка eglot на haskell-lsp server.
;; Last reviewed: 2026-06-06

(require 'cl-lib)
(require 'pro-compat)

;;; File extensions and mode mapping

(pro-compat--add-to-list-once 'auto-mode-alist '("\\.hs\\'" . haskell-mode))
(pro-compat--add-to-list-once 'auto-mode-alist '("\\.lhs\\'" . literate-haskell-mode))
(pro-compat--add-to-list-once 'auto-mode-alist '("\\.cabal\\'" . haskell-cabal-mode))
(pro-compat--add-to-list-once 'auto-mode-alist '("\\.stack\\.yaml\\'" . haskell-stack-yaml-mode))

;;; Lazy package loading

(defvar pro-haskell--mode-available nil
  "Non-nil when `haskell-mode' and friends are loaded in this session.")

(defun pro-haskell--ensure-mode ()
  "Load haskell-mode sub-features if available. Return non-nil on success."
  (unless pro-haskell--mode-available
    (when (or (pro--package-runtime-available-p 'haskell-mode)
              (ignore-errors (pro/packages-ensure 'haskell-mode t)))
      (condition-case _err
          (progn
            (require 'haskell-mode)
            (require 'haskell-indentation)
            (require 'haskell-font-lock)
            (require 'haskell-doc)
            (require 'haskell-cabal)
            (setq pro-haskell--mode-available t))
        (error
         (setq pro-haskell--mode-available nil)
         (message "[pro-haskell] haskell-mode require failed: %S" _err)))))
  pro-haskell--mode-available)

;;; Eglot / haskell-language-server

(defcustom pro-haskell-lsp-server-program '("haskell-language-server-wrapper" "--lsp")
  "Command line used to start haskell-language-server for eglot.
Either a list of strings, or a function returning a list. Override locally
to use a project-pinned binary (e.g. via `direnv' or `nix develop')."
  :type '(repeat string)
  :group 'pro-haskell)

(defcustom pro-haskell-enable-eglot t
  "If non-nil, automatically start HLS via eglot in Haskell buffers.
HLS is heavy (it eagerly type-checks the whole package, often 1-2 GiB RSS
and noticeable background I/O). Set to nil to fall back to plain haskell-mode
+ haskell-indentation (no LSP) — much lighter, but no jump-to-def /
hover / flycheck-style diagnostics."
  :type 'boolean
  :group 'pro-haskell)

(defun pro-haskell--register-eglot-server ()
  "Tell eglot to use `pro-haskell-lsp-server-program' for haskell buffers."
  (when (fboundp 'eglot-server-programs)
    (setq eglot-server-programs
          (cl-remove-if (lambda (entry)
                          (eq (car entry) 'haskell-mode))
                        eglot-server-programs))
    (add-to-list 'eglot-server-programs
                 `(haskell-mode . ,pro-haskell-lsp-server-program))
    (add-to-list 'eglot-server-programs
                 `(literate-haskell-mode . ,pro-haskell-lsp-server-program))))

;;; Per-buffer setup

(defun pro-haskell-setup ()
  "Предсказуемые локальные настройки Haskell-буфера.
Отключает табы, ставит ширину 2 (Haskell-стиль) и просит eglot/HLS
запуститься автоматически."
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 2)
  (when (and pro-haskell-enable-eglot
             (fboundp 'eglot-ensure)
             (executable-find "haskell-language-server-wrapper"))
    (eglot-ensure)))

;;; Helpers (interactive commands)

(defun pro-haskell-load-buffer ()
  "Load current Haskell buffer into the running session (cabal/ghci/repl).
Falls back to starting a fresh `haskell-interactive-mode' if no session exists."
  (interactive)
  (unless (derived-mode-p 'haskell-mode 'literate-haskell-mode)
    (user-error "pro-haskell-load-buffer: not a Haskell buffer"))
  (cond
   ((and (fboundp 'haskell-session-maybe)
         (condition-case nil (haskell-session-maybe) (error nil)))
    (haskell-process-load-file buffer-file-name))
   ((fboundp 'haskell-interactive-mode)
    (let ((haskell-process-type 'cabal-repl))
      (haskell-interactive-mode)
      (when buffer-file-name
        (haskell-process-load-file buffer-file-name))))
   (t
    (message "pro-haskell-load-buffer: haskell-interactive unavailable"))))

(defun pro-haskell-switch-to-repl ()
  "Switch to the Haskell REPL buffer, starting one if needed."
  (interactive)
  (cond
   ((fboundp 'haskell-interactive-mode)
    (let ((haskell-process-type 'cabal-repl))
      (haskell-interactive-mode)))
   (t
    (message "pro-haskell-switch-to-repl: haskell-interactive unavailable"))))

(defun pro-haskell-format-buffer ()
  "Format current Haskell buffer with fourmolu (best effort).
Falls back to a friendly message if fourmolu is not on PATH."
  (interactive)
  (unless (derived-mode-p 'haskell-mode 'literate-haskell-mode)
    (user-error "pro-haskell-format-buffer: not a Haskell buffer"))
  (if-let ((fourmolu (executable-find "fourmolu")))
      (let ((buf (current-buffer))
            (file (or buffer-file-name
                      (expand-file-name (format "/tmp/pro-haskell-%d.hs" (random 1000))))))
        (unless buffer-file-name (write-region (point-min) (point-max) file))
        (with-temp-buffer
          (let ((exit-code
                 (condition-case err
                     (call-process fourmolu nil t nil "--stdin-input-file" (file-name-nondirectory file))
                   (error -1)))
                (output (buffer-string)))
            (cond
             ((and (eq exit-code 0) (or buffer-file-name (= 0 (length output))))
              (message "pro-haskell: fourmolu: no changes"))
             ((eq exit-code 0)
              (with-current-buffer buf
                (erase-buffer)
                (insert output))
              (message "pro-haskell: fourmolu: reformatted"))
             (t
              (message "pro-haskell: fourmolu failed (exit=%d, see *Messages*): %s"
                       exit-code
                       (substring output 0 (min 200 (length output)))))))))
    (message "pro-haskell: fourmolu not found on PATH; install via modules/pro-haskell.nix")))

(defun pro-haskell-lint ()
  "Run hlint on the current buffer's file (or buffer contents if unnamed)."
  (interactive)
  (unless (derived-mode-p 'haskell-mode 'literate-haskell-mode)
    (user-error "pro-haskell-lint: not a Haskell buffer"))
  (if-let ((hlint (executable-find "hlint")))
      (let ((file (or buffer-file-name
                      (let ((tmp (make-temp-file "pro-haskell-" nil ".hs")))
                        (write-region (point-min) (point-max) tmp nil 'no-message)
                        tmp))))
        (compilation-start
         (format "%s %s" (shell-quote-argument hlint) (shell-quote-argument file))
         nil
         (lambda (_mode) "*hlint*")))
    (message "pro-haskell: hlint not found on PATH; install via modules/pro-haskell.nix")))

(defun pro-haskell-browse-haddock ()
  "Browse documentation for the symbol at point (or `haskell-doc' default)."
  (interactive)
  (cond
   ((fboundp 'haskell-doc-show)
    (haskell-doc-show))
   ((fboundp 'haskell-doc)
    (haskell-doc))
   (t
    (message "pro-haskell-browse-haddock: haskell-doc unavailable"))))

;;; Module bootstrap

(with-eval-after-load 'eglot
  (pro-haskell--register-eglot-server))

(pro-compat--add-hook-once 'haskell-mode-hook #'pro-haskell-setup)
(pro-compat--add-hook-once 'literate-haskell-mode-hook #'pro-haskell-setup)

;; Try to load haskell-mode eagerly at startup so the buffer is ready when
;; the user opens a .hs file. Failures are non-fatal: e.g. in containerized
;; runs without Nix profile, haskell-mode may be missing; the file will
;; still open in fundamental-mode and pro-haskell--ensure-mode can be
;; called later.
(ignore-errors (pro-haskell--ensure-mode))

(provide 'pro-haskell)

;;; pro-haskell.el ends here
