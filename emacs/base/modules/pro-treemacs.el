;;; pro-treemacs.el --- Treemacs wrappers and C-c T key bindings -*- lexical-binding: t; -*-
;;
;; Public commands:
;; - pro/treemacs           — открыть или toggle (если уже открыт)
;; - pro/treemacs-toggle    — явный toggle
;; - pro/treemacs-refresh   — обновить
;; - pro/treemacs-project   — treemacs для project root
;;
;; Биндинги C-c T * регистрируются через pro/register-module-keys.

(require 'subr-x)

(defgroup pro-treemacs nil
  "Treemacs helpers." :group 'pro)

(defcustom pro-treemacs-enable t
  "Enable treemacs integration." :type 'boolean :group 'pro-treemacs)

(defun pro-treemacs--available-p ()
  "Return non-nil если treemacs загружен."
  (or (featurep 'treemacs) (require 'treemacs nil t)))

(defun pro/treemacs ()
  "Open treemacs if closed, otherwise switch to its window.
Uses `pro-treemacs-toggle-window' style: if a treemacs window already
exists, select it; otherwise open one."
  (interactive)
  (if (pro-treemacs--available-p)
      (condition-case err
          (if (fboundp 'treemacs-select-window)
              (treemacs-select-window)
            (treemacs))
        (error (message "[pro-treemacs] treemacs failed: %S" err)))
    (message "[pro-treemacs] treemacs не загружен")))

(defun pro/treemacs-toggle ()
  "Toggle treemacs window: показать если скрыт, скрыть если виден."
  (interactive)
  (if (pro-treemacs--available-p)
      (condition-case err
          (if (fboundp 'treemacs-toggle)
              (treemacs-toggle)
            (pro/treemacs))
        (error (message "[pro-treemacs] treemacs-toggle failed: %S" err)))
    (message "[pro-treemacs] treemacs не загружен")))

(defun pro/treemacs-refresh ()
  "Refresh treemacs buffer (re-read filesystem)."
  (interactive)
  (if (pro-treemacs--available-p)
      (condition-case err
          (cond
           ((fboundp 'treemacs-refresh) (treemacs-refresh))
           ((fboundp 'treemacs-revert) (treemacs-revert))
           (t (revert-buffer t t t)))
        (error (message "[pro-treemacs] refresh failed: %S" err)))
    (message "[pro-treemacs] treemacs не загружен")))

(defun pro/treemacs-project ()
  "Open treemacs in project root (если projectile доступен)."
  (interactive)
  (if (pro-treemacs--available-p)
      (condition-case err
          (let ((default-directory (or (and (fboundp 'projectile-project-root)
                                            (projectile-project-root))
                                       default-directory)))
            (pro/treemacs))
        (error (message "[pro-treemacs] project open failed: %S" err)))
    (message "[pro-treemacs] treemacs не загружен")))

;; ── C-c T sub-prefix keymap ─────────────────────────────────────────────
;; `C-c T' is a prefix key; we install a sparse keymap so children like
;; `C-c T t', `C-c T r', etc. attach to it instead of conflicting with
;; the parent binding.  `pro-keys.el' attaches this keymap to
;; `global-map' as part of parsing the Org-table — see emacs-keys.org.

(defvar pro-treemacs-prefix-map
  (let ((map (make-sparse-keymap)))
    ;; Pre-populate children so that even before pro-keys.el re-binds
    ;; anything, the prefix is functional.
    (define-key map (kbd "t") #'pro/treemacs-toggle)
    (define-key map (kbd "r") #'pro/treemacs-refresh)
    (define-key map (kbd "p") #'pro/treemacs-project)
    (define-key map (kbd "d") #'treemacs-delete-window)
    (define-key map (kbd "?") #'pro/tree-transient)
    map)
  "Keymap for `C-c T' prefix (treemacs commands).")

;; ── Register suggestions for keys layer ─────────────────────────────────

(with-eval-after-load 'pro-keys
  (when (fboundp 'pro/register-module-keys)
    (pro/register-module-keys
     'treemacs
     ;; `C-c T' itself points to the prefix keymap.  Children are bound
     ;; automatically by `pro-keys-apply-binding' when the parent is a
     ;; keymap.
     '(("C-c T" . pro-treemacs-prefix-map)
       ("C-c x d" . pro/treemacs)))))

(provide 'pro-treemacs)
;;; pro-treemacs.el ends here
