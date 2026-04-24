;;; pro-ui.el --- визуальная среда -*- lexical-binding: t; -*-

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

(defcustom pro-ui-default-theme 'tao-yang
  "Default theme to attempt to load early. Set to nil to disable.
By default pro-nix will attempt to load tao-yang theme if available." 
  :type '(choice (const :tag "none" nil) symbol)
  :group 'pro-ui)

(defcustom pro-ui-modeline-style 'shaoline
  "Modeline style: 'minimal, 'shaoline or 'doom. Defaults to 'shaoline.
Modeline packages are only enabled if available and if this value
is set accordingly." 
  :type '(choice (const minimal) (const shaoline) (const doom))
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

    ;; Try to enable icons inside minibuffer completion lists (consult/vertico)
    ;; Prefer `nerd-icons' integration on NixOS where available; fallback to
    ;; `all-the-icons' if present. Load these integrations lazily when consult
    ;; or vertico is loaded to avoid startup cost.
    (with-eval-after-load 'consult
      (cond
       ((pro-ui--try-require 'nerd-icons)
        (when (pro-ui--try-require 'nerd-icons-completion)
          (when (fboundp 'nerd-icons-completion-mode)
            (nerd-icons-completion-mode 1))))
       ((pro-ui--try-require 'all-the-icons)
        (when (pro-ui--try-require 'all-the-icons-completion)
          (when (fboundp 'all-the-icons-completion-mode)
            (all-the-icons-completion-mode 1))))))

    ;; Provide a small minibuffer hint about navigation and actions to help
    ;; discoverability. This message is non-intrusive and displays in the echo
    ;; area when minibuffer is entered for the first time in a session.
    (defvar pro--minibuffer-hint-shown nil "Whether the minibuffer hint was shown this session.")
    (defun pro--show-minibuffer-hint-once ()
      "Show a short help line for minibuffer navigation the first time only."
      (unless pro--minibuffer-hint-shown
        (message "TAB/C-i: next • S-TAB: prev • C-n/C-p/C-j/C-k: navigate • C-.: actions • M-.: preview")
        (setq pro--minibuffer-hint-shown t)))
(add-hook 'minibuffer-setup-hook #'pro--show-minibuffer-hint-once))

)

;; Wire ui subsystems implemented in separate files (pro-nix style).
(when (file-readable-p (expand-file-name "ui-fonts.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-fonts.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))
(when (file-readable-p (expand-file-name "ui-completion.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-completion.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))
(when (file-readable-p (expand-file-name "ui-icons.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-icons.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))
(when (file-readable-p (expand-file-name "ui-modeline.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-modeline.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))
(when (file-readable-p (expand-file-name "ui-theme.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-theme.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))
(when (file-readable-p (expand-file-name "ui-fringes.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-fringes.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))
(when (file-readable-p (expand-file-name "ui-tty.el" (file-name-directory (or load-file-name buffer-file-name))))
  (ignore-errors (load (expand-file-name "ui-tty.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)))

  ;; Embark: enable if available to provide quick-actions for candidates
  (when (pro-ui--try-require 'embark)
    (with-eval-after-load 'embark
      ;; Provide a concise keymap for common actions to be discoverable.
      (let ((map (make-sparse-keymap)))
        (define-key map (kbd "o") #'embark-act) ;; open/default
        (define-key map (kbd "d") #'embark-dwim) ;; reveal / dired / default
        (define-key map (kbd "y") #'embark-copy) ;; copy
        (define-key map (kbd "g") #'embark-collect) ;; collect for further ops
        ;; Attach this map as a summary for which-key if available
        (when (pro-ui--try-require 'which-key)
          (with-eval-after-load 'which-key
            (which-key-add-key-based-replacements "C-." "Embark actions")))))
    ;; Register embark-consult integration when available
    (when (pro-ui--try-require 'embark-consult)
      (with-eval-after-load 'embark-consult
        (when (fboundp 'embark-consult-export)
          (ignore-errors (embark-consult-export)))))

  ;; Ensure a convenient binding for embark-act is available in minibuffer
  (when (pro-ui--try-require 'embark)
    (define-key minibuffer-local-map (kbd "C-.") #'embark-act)
    (define-key minibuffer-local-completion-map (kbd "C-.") #'embark-act)
    ;; Provide a global convenience binding when which-key is present
    (when (pro-ui--try-require 'which-key)
      (global-set-key (kbd "C-.") #'embark-act))))

;; Embark-Consult: configure default actions and mappings for common types
(when (pro-ui--try-require 'embark-consult)
  (with-eval-after-load 'embark-consult
    ;; Ensure embark-consult registers useful collectors
    (add-to-list 'embark-consult-sources 'consult--source-project-buffer)))

    

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

    ;; Improve corfu margin formatting experience if kind-icon present.
    ;; Guard with `fboundp' in case the package is partially loaded and the
    ;; formatter symbol is not yet defined.
    (when (and (pro-ui--try-require 'kind-icon)
               (boundp 'corfu-margin-formatters)
               (fboundp 'kind-icon-margin-formatter))
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
    (when (and (pro-ui--try-require 'kind-icon) (boundp 'corfu-margin-formatters) (fboundp 'kind-icon-margin-formatter))
      (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter)))

(provide 'pro-ui)

;;; pro-ui.el ends here

;; Helper: check icon fonts availability and print install guidance
(defun pro-ui-check-icon-fonts ()
  "Check for common icon fonts (Nerd Fonts / all-the-icons) and print guidance.

This function checks for a few popular patched font families used by
`nerd-icons`/`all-the-icons`. If none are found, it prints a short help
message with recommendations (manual and Home-Manager snippets).
"
  (interactive)
  (let ((candidates '("FiraCode Nerd Font" "Hack Nerd Font" "DejaVu Sans Mono Nerd Font" "Nerd Font" "Aller"))
        found)
    (dolist (f candidates)
      (when (pro-ui--font-available-p f)
        (push f found)))
    (if found
        (message "Icon fonts available: %s" (string-join (nreverse found) ", "))
      (message "No Nerd / icon fonts found. See docs/ICON-FONTS.md for installation instructions."))))
