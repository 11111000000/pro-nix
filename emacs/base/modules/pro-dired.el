;;; pro-dired.el --- Dired helpers for pro-nix -*- lexical-binding: t; -*-
;; Minimal, well-tested dired configuration ported from ~/pro with guards

(require 'subr-x)

(defcustom pro-dired-enable t
  "Enable pro dired helpers.
Set to nil to disable."
  :type 'boolean :group 'pro)

(when pro-dired-enable
  (when (require 'dired nil t)
    
    (defun pro/dired-reload-elisp-here ()
      "Byte-compile and reload the .el file at point in dired.

Использует `pro/reload-file' — гарантирует реальное перевыполнение
top-level-форм (`defvar', `defcustom', `defun', `add-hook', и т.п.)
в текущей сессии Emacs, без рестарта."
      (interactive)
      (let ((file (dired-get-filename)))
        (unless (string-match-p "\\.el\\'" file)
          (user-error "Not an .el file: %s" file))
        (pro/reload-file file)
        (message "Reloaded %s" file)))

    (defun pro/dired-reload-elisp-dir-recursive ()
      "Рекурсивно byte-compile и reload всех .el в текущей папке dired.

Обход делается рекурсивно (`directory-files-recursively'), но
пропускаются каталоги, имя компоненты пути которых начинается с
`.git' / `.dir-locals' / `.vscode' / `.idea' / `.cache' / `.stack-work'
— чтобы случайно не дёрнуть чужой код. Каждый .el обрабатывается
через `pro/reload-file' — top-level формы реально перевыполняются.

Если на каком-то файле load падает — он пропускается, обход
продолжается. По окончании выводит итог: N ok, M failed."
      (interactive)
      (let* ((dir (or (and (fboundp 'dired-current-directory)
                           (dired-current-directory))
                      default-directory))
             (files (directory-files-recursively
                     dir "\\.el\\'" nil
                     ;; Не лезть в служебные / сборочные каталоги.
                     (lambda (name)
                       (let ((base (file-name-nondirectory name)))
                         (not (string-match-p
                               "^[.]\\(git\\|dir-locals\\|vscode\\|idea\\|cache\\|stack-work\\|cabal\\|ghc\\.environment\\)$"
                               base))))))
             (ok 0) (fail 0) (failed-names '()))
        (dolist (f files)
          (condition-case err
              (progn (pro/reload-file f) (setq ok (1+ ok)))
            (error
             (setq fail (1+ fail))
             (push (file-name-nondirectory f) failed-names))))
        (message "pro/dired-reload-elisp-dir: %d ok, %d failed in %s%s"
                 ok fail dir
                 (if failed-names
                     (concat " (failed: "
                             (mapconcat #'identity (nreverse failed-names) ", ")
                             ")")
                   ""))))

    ;; basic keybindings and hooks
    ;;
    ;; Привязки делаем через `dired-mode-hook' instead of
    ;; `with-eval-after-load 'dired' — последнее работает только на
    ;; момент загрузки `pro-dired'. Если позже подключается `dired-x'
    ;; или `wdired', их define-key может перетереть наши. Через hook
    ;; привязки ставятся на КАЖДЫЙ dired-буфер и перебить их гораздо
    ;; сложнее.
    (defun pro-dired--install-keys ()
      "Установить pro-dired keybindings в текущем dired-буфере."
      (when (derived-mode-p 'dired-mode)
        (define-key dired-mode-map (kbd "j") #'dired-next-line)
        (define-key dired-mode-map (kbd "k") #'dired-previous-line)
        (define-key dired-mode-map (kbd "l") #'dired-find-file)
        (define-key dired-mode-map (kbd "f") #'dired-find-file)
        (define-key dired-mode-map (kbd "o") #'dired-find-file)
        (define-key dired-mode-map (kbd "RET") #'dired-find-file)
        (define-key dired-mode-map (kbd "h") #'dired-up-directory)
        (define-key dired-mode-map (kbd "^") #'dired-up-directory)
        (define-key dired-mode-map (kbd "C-c r") #'pro/dired-reload-elisp-here)
        (define-key dired-mode-map (kbd "C-c C-r") #'pro/dired-reload-elisp-dir-recursive)))
    (add-hook 'dired-mode-hook #'pro-dired--install-keys)
    ;; Если dired уже загружен и есть открытые буферы — применить сразу.
    (when (and (boundp 'dired-mode-map) (fboundp 'dired-mode))
      (pro-dired--install-keys))

    ;; Hooks and settings
    (add-hook 'dired-mode-hook #'dired-hide-details-mode)
    (add-hook 'dired-mode-hook #'hl-line-mode)

    ;; Listing format customization: keep long format as default to preserve tests
    (defcustom pro-dired-prefer-short nil
      "If non-nil, use compact/short `ls' output in dired (one-file-per-line).
Default is nil to preserve test compatibility and familiar long listing."
      :type 'boolean :group 'pro)

    (defcustom pro-dired-long-listing-switches "-aBhlv --group-directories-first"
      "The long-format listing switches used by pro dired (default)."
      :type 'string :group 'pro)

    (defcustom pro-dired-short-listing-switches "-aB1 --group-directories-first"
      "The short/compact listing switches used when `pro-dired-prefer-short' is non-nil.
This produces one file per line with minimal metadata."
      :type 'string :group 'pro)

    (setq-default dired-listing-switches
                  (if pro-dired-prefer-short
                      pro-dired-short-listing-switches
                    pro-dired-long-listing-switches))

    (defun pro/dired-toggle-listing-format ()
      "Toggle between pro dired long and short listing formats.
This flips `pro-dired-prefer-short' and updates `dired-listing-switches' for new buffers."
      (interactive)
      (setq pro-dired-prefer-short (not pro-dired-prefer-short))
      (setq-default dired-listing-switches
                    (if pro-dired-prefer-short
                        pro-dired-short-listing-switches
                      pro-dired-long-listing-switches))
      (message "pro-dired: listing-format => %s"
               (if pro-dired-prefer-short "short" "long")))
    (setq ls-lisp-dirs-first t)
    (setq ls-lisp-use-insert-directory-program nil)
    (setq dired-dwim-target t)
    (setq insert-directory-program "ls")
    (setq dired-use-ls-dired t)
    (setq dired-auto-revert-buffer t)
    ;; Disabled for I/O: pro-dired previously enabled global revert for
    ;; non-file buffers (magit-status, help, *Messages*, *Compile*, ...).
    ;; With eglot + magit + projectile + treemacs running, this made Emacs
    ;; re-read all such buffers periodically and accounted for a large share
    ;; of background disk I/O. File buffers still auto-revert by default;
    ;; only the non-file variant is disabled. Flip back to `t' if you want
    ;; live-updating *Help* / *Messages* / etc.
    (setq global-auto-revert-non-file-buffers nil)
    (setq dired-hide-details-hide-symlink-targets nil)
    ;; wdired: enable quick editing
    (when (require 'wdired nil t)
      (with-eval-after-load 'dired
        (define-key dired-mode-map (kbd "C-c C-c") #'wdired-change-to-wdired-mode)
        (with-eval-after-load 'wdired
          (define-key wdired-mode-map (kbd "C-c C-r") #'replace-string)
          (define-key wdired-mode-map (kbd "C-c r") #'replace-regexp)
          (define-key wdired-mode-map (kbd "C-g C-g") #'wdired-exit)
          (define-key wdired-mode-map (kbd "ESC") #'wdired-exit))))
    ;; Optional: treemacs icons in dired when available via ui layer
    (when (and (fboundp 'pro-ui--try-require)
               (pro-ui--try-require 'treemacs-icons-dired))
      (add-hook 'dired-mode-hook #'treemacs-icons-dired-enable-once))
    )
  )

(provide 'pro-dired)

;;; pro-dired.el ends here
