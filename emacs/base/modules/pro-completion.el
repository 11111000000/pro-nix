;;; pro-completion.el --- Modern completion stack glue -*- lexical-binding: t; -*-
;; Integrates Vertico/Consult with Corfu/Cape for a unified completion UX.
;; This module prefers packages provided by Nix, falls back to prompt-and-install
;; via `pro-packages--maybe-install' when allowed, and enables sensible
;; defaults for both GUI and TTY sessions.

(defgroup pro-completion nil
  "Completion stack configuration for pro Emacs profile."
  :group 'pro-ui)

(defcustom pro-completion-enable-posframe nil
  "Enable corfu-posframe for child-frame based completion in GUI.
Disable if you observe frame jitter on your setup."
  :type 'boolean
  :group 'pro-completion)

(defcustom pro-completion-auto-prefix 3
  "Minimum prefix length before corfu auto-starts when `corfu-auto' is enabled."
  :type 'integer
  :group 'pro-completion)

(defcustom pro-completion-auto-delay 0.25
  "Delay before Corfu auto popup appears."
  :type 'number
  :group 'pro-completion)

(defvar pro-completion--kind-icon-installed nil
  "Non-nil when kind-icon margin formatter was installed.")

(defun pro-completion--disable-ispell-capf ()
  "Remove `ispell-completion-at-point' from `completion-at-point-functions'."
  (setq-local completion-at-point-functions
              (remq #'ispell-completion-at-point completion-at-point-functions)))

;; Corfu: in-buffer popup completion
(when (or (pro--package-provided-p 'corfu) (pro-packages--maybe-install 'corfu t) (require 'corfu nil t))
  (setq corfu-auto t
        corfu-auto-prefix pro-completion-auto-prefix
        corfu-auto-delay pro-completion-auto-delay
        corfu-cycle t
        corfu-count 14
        corfu-separator ?\s
        corfu-echo-documentation nil
        corfu-preselect 'prompt
        corfu-min-width 5
        corfu-max-width 70)
  (when (fboundp 'global-corfu-mode) (global-corfu-mode 1))
  (when (fboundp 'corfu-history-mode) (corfu-history-mode 1)))

;; Явные клавиши Tab/Shift-Tab для навигации по кандидатам corfu
(with-eval-after-load 'corfu
  (when (boundp 'corfu-map)
    (define-key corfu-map (kbd "TAB") #'corfu-next)
    (define-key corfu-map (kbd "<tab>") #'corfu-next)
    (define-key corfu-map (kbd "<backtab>") #'corfu-previous)
    (define-key corfu-map (kbd "S-TAB") #'corfu-previous)))

;; Corfu in TTY
(when (and (not (display-graphic-p))
           (or (pro--package-provided-p 'corfu-terminal) (pro-packages--maybe-install 'corfu-terminal t) (require 'corfu-terminal nil t)))
  (when (fboundp 'corfu-terminal-mode) (corfu-terminal-mode 1)))

;; Optional posframe backend for GUI
(when (and pro-completion-enable-posframe (display-graphic-p))
  (when (or (pro--package-provided-p 'corfu-posframe) (pro-packages--maybe-install 'corfu-posframe t) (require 'corfu-posframe nil t))
    (when (fboundp 'corfu-posframe-mode) (corfu-posframe-mode 1))))

;; Cape: add useful CAPF backends
(when (or (pro--package-provided-p 'cape) (pro-packages--maybe-install 'cape t) (require 'cape nil t))
  ;; Ensure common cape submodules are loaded so their symbols (cape-keyword,
  ;; cape-symbol etc.) are defined immediately. Some cape helpers are in
  ;; separate files (cape-keyword) and may not be autoloaded in all setups.
  (ignore-errors (require 'cape-keyword nil t))
  (ignore-errors (require 'cape-dabbrev nil t))
  ;; order: specific -> general
  (dolist (fn '(cape-file cape-keyword))
    (unless (member fn completion-at-point-functions)
      (add-to-list 'completion-at-point-functions fn)))
  (add-hook 'prog-mode-hook
            (lambda ()
              (unless (member #'cape-dabbrev completion-at-point-functions)
                (add-to-list 'completion-at-point-functions #'cape-dabbrev))))

  ;; Fallback shims: define lightweight cape helpers if real package is
  ;; not available. Placing them outside the `when' ensures they exist even
  ;; if cape wasn't installed; they are simple wrappers over
  ;; `completion-at-point' and safe to call.
  (unless (fboundp 'cape-keyword)
    (defun cape-keyword (&optional interactive)
      "Fallback: complete language keywords at point via `completion-at-point'."
      (interactive)
      (let ((bounds (bounds-of-thing-at-point 'symbol)))
        (when bounds
          (completion-at-point (car bounds) (cdr bounds)))))
    (put 'cape-keyword 'no-side-effect t))

  (unless (fboundp 'cape-symbol)
    (defun cape-symbol (&optional interactive)
      "Fallback: complete symbols at point via `completion-at-point'."
      (interactive)
      (let ((bounds (bounds-of-thing-at-point 'symbol)))
        (when bounds
          (completion-at-point (car bounds) (cdr bounds)))))
    (put 'cape-symbol 'no-side-effect t))
  ;; Disable ispell CAPF where it causes slowness
  (add-hook 'prog-mode-hook #'pro-completion--disable-ispell-capf)
  (add-hook 'text-mode-hook #'pro-completion--disable-ispell-capf))

;; Optional candidate icons in Corfu margin
(when (and (or (pro--package-provided-p 'kind-icon) (pro-packages--maybe-install 'kind-icon t) (require 'kind-icon nil t))
           (boundp 'corfu-margin-formatters)
           (fboundp 'kind-icon-margin-formatter)
           (not pro-completion--kind-icon-installed))
  (setq pro-completion--kind-icon-installed t)
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

;; Minibuffer: disable Corfu completely when Vertico/MCT are active
(defun pro-completion--maybe-enable-corfu-in-minibuffer ()
  "Configure Corfu in minibuffer unless Vertico/MCT is active.

We intentionally do NOT enable `corfu-mode' in the minibuffer here — the
minibuffer UX is better served by Vertico/Consult. We disable both
corfu-auto and corfu-mode when any minibuffer completion UI is active."
  (cond
   ((or (bound-and-true-p vertico--input) (bound-and-true-p mct--active))
    (when (boundp 'corfu-mode)
      (corfu-mode -1))
    (when (boundp 'corfu-auto)
      (setq-local corfu-auto nil)))
   (t
    (when (boundp 'corfu-auto)
      (setq-local corfu-auto t)))))
(add-hook 'minibuffer-setup-hook #'pro-completion--maybe-enable-corfu-in-minibuffer)

;; Orderless включаем только после успешной загрузки стиля, чтобы не получать ошибку `invalid completion style orderless' на старте.
(when (boundp 'completion-category-overrides)
  (setq completion-category-overrides
        (append '((file (styles partial-completion basic)))
                (when (require 'orderless nil t)
                  '((command (styles orderless basic))
                    (symbol (styles orderless basic)))))))

(provide 'pro-completion)

;;; pro-completion.el ends here
