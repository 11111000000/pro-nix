;;; ui.el --- визуальная среда -*- lexical-binding: t; -*-

;; Этот модуль собирает внешний вид так, чтобы он был тихим, читаемым и полезным.

(require 'subr-x)

(defcustom pro-ui-code-font-family "Aporetic Sans Mono"
  "Шрифт для кода."
  :type 'string
  :group 'pro-ui)

(defcustom pro-ui-text-font-family "Aporetic Sans"
  "Шрифт для текста интерфейса."
  :type 'string
  :group 'pro-ui)

(defcustom pro-ui-font-height 130
  "Высота шрифта в десятых долях пункта."
  :type 'integer
  :group 'pro-ui)

(defcustom pro-ui-enable-ligatures t
  "Включать ли лигатуры в коде."
  :type 'boolean
  :group 'pro-ui)

(defcustom pro-ui-enable-icons t
  "Включать ли иконки в UI-слое."
  :type 'boolean
  :group 'pro-ui)

(defun pro-ui--font-available-p (family)
  "Проверить, доступен ли шрифт FAMILY."
  (find-font (font-spec :family family)))

(defun pro-ui--first-available-font (families)
  "Вернуть первый доступный шрифт из списка FAMILIES."
  (catch 'found
    (dolist (family families)
      (when (pro-ui--font-available-p family)
        (throw 'found family)))
    nil))

(defun pro-ui-apply-fonts ()
  "Применить шрифты к графическому фрейму."
  (when (display-graphic-p)
    (let ((code-font (or (pro-ui--first-available-font '("Fira Code" "JetBrains Mono" "Aporetic Sans Mono" "DejaVu Sans Mono"))
                         pro-ui-code-font-family))
          (text-font (or (pro-ui--first-available-font '("Fira Sans" "Inter" "Aporetic Sans" "DejaVu Sans"))
                         pro-ui-text-font-family)))
      (set-face-attribute 'default nil :family code-font :height pro-ui-font-height)
      (set-face-attribute 'fixed-pitch nil :family code-font :height 1.0)
      (set-face-attribute 'variable-pitch nil :family text-font :height 1.0)
      (push `(font . ,(format "%s-%d" code-font (/ pro-ui-font-height 10))) default-frame-alist)
      (push `(font . ,(format "%s-%d" code-font (/ pro-ui-font-height 10))) initial-frame-alist))))

(defun pro-ui-apply-ligatures ()
  "Включить лигатуры, если они доступны."
  (when (and pro-ui-enable-ligatures (require 'ligature nil t))
    (ligature-set-ligatures 'prog-mode
                            '("www" "|||" "|>" ":=" ":-" ":>" "->" "->>" "-->" "<=" ">=" "==" "===" "!=" "&&" "||" "///" "/*" "*/" "::" "::=" "++" "**" "~~" "%%"))
    (global-ligature-mode t)))

(defun pro-ui--try-require (feature)
  "Безопасно подключить FEATURE."
  (or (and (boundp 'pro-packages-provided-by-nix)
           (memq feature pro-packages-provided-by-nix)
           (require feature nil t))
      (when (and (fboundp 'pro-packages--maybe-install)
                 (pro-packages--maybe-install feature t))
        (require feature nil t))))

(defun pro-ui-apply-icons ()
  "Подключить полезные иконки без обязательной зависимости."
  (when (and pro-ui-enable-icons (display-graphic-p))
    ;; Try preferred icon libraries in order of quality/availability.
    ;; all-the-icons: classic emacs icon set; nerd-icons / nerd-icons-ibuffer if available;
    ;; kind-icon used for completion margins.
    (cond
     ((pro-ui--try-require 'nerd-icons)
      (when (pro-ui--try-require 'nerd-icons-ibuffer)
        (add-hook 'ibuffer-mode-hook #'nerd-icons-ibuffer-mode))
      (when (pro-ui--try-require 'all-the-icons)
        (setq all-the-icons-scale-factor 1.0)))
     ((pro-ui--try-require 'all-the-icons)
      (setq all-the-icons-scale-factor 1.0)))

    ;; Completion margin icons (non-fatal)
    (when (pro-ui--try-require 'kind-icon)
      (when (boundp 'corfu-margin-formatters)
        (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter)))

    ;; Dired icons via treemacs integration when available
    (when (pro-ui--try-require 'treemacs-icons-dired)
      (add-hook 'dired-mode-hook #'treemacs-icons-dired-enable-once))

    ;; Soft guards: if system reports limited color support, reduce icon work
    (when (and (display-graphic-p)
               (or (not (display-color-p)) (< (display-color-cells) 256)))
      (message "[pro-ui] limited color support detected; disabling heavy icon features")
      ;; remove heavy hooks if any
      (when (fboundp 'treemacs-icons-dired-enable-once)
        (remove-hook 'dired-mode-hook #'treemacs-icons-dired-enable-once)))

    ;; If running in a low-color or headless environment, avoid heavy icon setup
    (when (or (not (display-graphic-p)) (not (display-graphic-p)))
      ;; no-op: already guarded above but keep explicit fallback for clarity
      nil)))

(defun pro-ui-apply-tabs ()
  "Подключить pro-tabs, если пакет доступен."
  (when (display-graphic-p)
    (when (pro-ui--try-require 'pro-tabs)
      (setq pro-tabs-enable-icons t)
      (when (fboundp 'pro-tabs-mode)
        (pro-tabs-mode 1)))))

(defun pro-ui-apply-completion ()
  "Подключить полезные подсказки для завершения."
  (when (display-graphic-p)
    ;; Configure Corfu (in-buffer completion UI) with sane defaults.
    (when (pro-ui--try-require 'corfu)
      ;; Prefer automatic completion but keep it conservative when needed.
      ;; Conservative defaults tuned for responsiveness and minimal noise.
      (setq corfu-auto t
            corfu-auto-prefix 2
            corfu-auto-delay 0.12
            corfu-cycle t
            corfu-count 10
            corfu-separator ?\s
            corfu-echo-documentation nil
            corfu-preselect 'prompt
            corfu-min-width 40
            corfu-max-width 120)
      (when (fboundp 'global-corfu-mode) (global-corfu-mode 1))
      (when (fboundp 'corfu-history-mode) (corfu-history-mode 1)))

    ;; Integrate Cape (completion at point extensions) if available.
    (when (pro-ui--try-require 'cape)
      ;; Common useful CAPF backends. Order matters: more specific first.
      (dolist (fn '(cape-file cape-keyword cape-dabbrev))
        (unless (member fn completion-at-point-functions)
          (add-to-list 'completion-at-point-functions fn)))
      ;; Provide a helper to disable slow ispell capf in programming/text modes.
      (defun pro-ui--disable-ispell-capf ()
        "Remove `ispell-completion-at-point' from `completion-at-point-functions'."
        (setq-local completion-at-point-functions
                    (remq #'ispell-completion-at-point completion-at-point-functions)))
      (add-hook 'prog-mode-hook #'pro-ui--disable-ispell-capf)
      (add-hook 'text-mode-hook #'pro-ui--disable-ispell-capf))

    ;; Enable Corfu in the minibuffer when Vertico/MCT are not active.
    (defun pro-ui--maybe-enable-corfu-in-minibuffer ()
      "Enable `corfu-mode' in minibuffer unless Vertico/MCT is active." 
      (unless (or (bound-and-true-p vertico--input) (bound-and-true-p mct--active))
        (setq-local corfu-auto nil) ; prefer manual completion in minibuffer
        (when (fboundp 'corfu-mode) (corfu-mode 1))))
    (add-hook 'minibuffer-setup-hook #'pro-ui--maybe-enable-corfu-in-minibuffer)

    ;; Improve corfu margin formatting experience if kind-icon present
    (when (and (pro-ui--try-require 'kind-icon) (boundp 'corfu-margin-formatters))
      (setq kind-icon-default-face 'corfu-default) ;; integrate with corfu theme
      (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

    ;; Gentle corfu face polish for better contrast in common themes.
    (when (fboundp 'set-face-attribute)
      (set-face-attribute 'corfu-default nil :background "#1c1f26" :foreground "#dcdfe4")
      (set-face-attribute 'corfu-current nil :background "#2a2f36" :foreground "#ffffff" :weight 'bold)))

    ;; Vertico keybindings: make C-n/C-p behave like minibuffer navigation
    (when (and (boundp 'vertico-map) (keymapp vertico-map))
      (define-key vertico-map (kbd "C-n") #'vertico-next)
      (define-key vertico-map (kbd "C-p") #'vertico-previous)
      (define-key vertico-map (kbd "M-n") #'vertico-next)
      (define-key vertico-map (kbd "M-p") #'vertico-previous))

    ;; Corfu for terminal sessions.
    (unless (display-graphic-p)
      (when (pro-ui--try-require 'corfu-terminal)
        (when (fboundp 'corfu-terminal-mode) (corfu-terminal-mode 1))))

    ;; Optional cosmetics: candidate icons in the margin.
    (when (and (pro-ui--try-require 'kind-icon) (boundp 'corfu-margin-formatters))
      (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter)))

(provide 'ui)
