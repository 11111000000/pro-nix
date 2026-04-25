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

(defcustom pro-completion-auto-prefix 2
  "Minimum prefix length before corfu auto-starts when `corfu-auto' is enabled." 
  :type 'integer
  :group 'pro-completion)

(defun pro-completion--disable-ispell-capf ()
  "Remove `ispell-completion-at-point' from `completion-at-point-functions'."
  (setq-local completion-at-point-functions
              (remq #'ispell-completion-at-point completion-at-point-functions)))

;; Corfu: in-buffer popup completion
(when (or (pro--package-provided-p 'corfu) (pro-packages--maybe-install 'corfu t) (require 'corfu nil t))
  (setq corfu-auto t
        corfu-auto-prefix pro-completion-auto-prefix
        corfu-auto-delay 0.2
        corfu-cycle t
        corfu-count 14
        corfu-separator ?\s
        corfu-echo-documentation nil
        corfu-preselect 'prompt
        corfu-min-width 5
        corfu-max-width 70)
  (when (fboundp 'global-corfu-mode) (global-corfu-mode 1))
  (when (fboundp 'corfu-history-mode) (corfu-history-mode 1)))

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
  (dolist (fn '(cape-file cape-keyword cape-dabbrev))
    (unless (member fn completion-at-point-functions)
      (add-to-list 'completion-at-point-functions fn)))
  ;; Disable ispell CAPF where it causes slowness
  (add-hook 'prog-mode-hook #'pro-completion--disable-ispell-capf)
  (add-hook 'text-mode-hook #'pro-completion--disable-ispell-capf))

;; Optional candidate icons in Corfu margin
(when (and (or (pro--package-provided-p 'kind-icon) (pro-packages--maybe-install 'kind-icon t) (require 'kind-icon nil t))
           (boundp 'corfu-margin-formatters)
           (fboundp 'kind-icon-margin-formatter))
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

;; Minibuffer: enable Corfu only when Vertico/MCT aren't active
  (defun pro-completion--maybe-enable-corfu-in-minibuffer ()
  "Configure Corfu in minibuffer unless Vertico/MCT is active.

We intentionally do NOT enable `corfu-mode' in the minibuffer here — the
minibuffer UX is better served by Vertico/Consult. We only disable automatic
popup behaviour (corfu-auto) when Corfu is present, to avoid accidental
in-buffer style popups during minibuffer commands when Vertico isn't active.
" 
  (unless (or (bound-and-true-p vertico--input) (bound-and-true-p mct--active))
    (when (boundp 'corfu-auto)
      (setq-local corfu-auto nil))
    ;; Ensure Corfu does not activate inside the minibuffer. Disabling the
    ;; buffer-local `corfu-mode' here is safe even when `global-corfu-mode' is
    ;; enabled because it only affects the minibuffer buffer.
    (when (fboundp 'corfu-mode)
      (corfu-mode -1))))
(add-hook 'minibuffer-setup-hook #'pro-completion--maybe-enable-corfu-in-minibuffer)

;; Recommend completion-style overrides for reliable file/command matching.
(when (boundp 'completion-category-overrides)
  (setq completion-category-overrides '((file (styles partial-completion basic))
                                         (command (styles orderless basic)))))

(provide 'pro-completion)

;;; pro-completion.el ends here
