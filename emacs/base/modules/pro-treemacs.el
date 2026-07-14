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

;; ── Register suggestions for keys layer ─────────────────────────────────

(with-eval-after-load 'pro-keys
  (when (fboundp 'pro/register-module-keys)
    (pro/register-module-keys
     'treemacs
     '(("C-c T" . pro/treemacs)
       ("C-c T t" . pro/treemacs-toggle)
       ("C-c T r" . pro/treemacs-refresh)
       ("C-c T p" . pro/treemacs-project)
       ("C-c T d" . treemacs-delete-window)
       ("C-c T ?" . pro/tree-transient)
       ("C-c x d" . pro/treemacs)))))

(provide 'pro-treemacs)
;;; pro-treemacs.el ends here
