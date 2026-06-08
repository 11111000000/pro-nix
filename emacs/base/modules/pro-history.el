;;; pro-history.el --- Time Machine: undo-tree, sessions, kill-ring, layout snapshots -*- lexical-binding: t; -*-
;; Назначение: централизованная политика хранения временных файлов, backup-ов
;; и пользовательского state + полноценный «Time Machine» для истории Emacs.
;;
;; Контракт:
;; - выносит state в XDG-подобный layout:
;;   - state:   ${XDG_STATE_HOME:-~/.local/state}/pro-emacs/
;;   - cache:   ${XDG_CACHE_HOME:-~/.cache}/pro-emacs/
;; - не добавляет data-каталоги в `load-path`.
;; - на этапе загрузки создает необходимые каталоги в idempotent-режиме.
;; - undo-tree с бесшумным автосохранением/восстановлением (без y-or-n-p).
;; - goto-last-change / goto-last-point для навигации по правкам.
;; - winner-mode, desktop, saveplace, recentf.
;; - kill-ring snapshot save/restore.
;; - интерактивные команды: очистка undo, меню, snapshot layout.
;; - биндинги регистрируются через pro/register-module-keys (не global-set-key!).
;;
;; Побочные эффекты: модифицирует Emacs переменные backup/auto-save/savehist/recentf/save-place.
;; Проверка: emacs/base/tests/test-history.el (headless ERT)

(require 'subr-x)

;; ═══════════════════════════════════════════════════════════════════════════
;; 1. Customization group
;; ═══════════════════════════════════════════════════════════════════════════

(defgroup pro-history nil
  "pro: runtime history, temp file policies, and Time Machine commands."
  :group 'convenience)

;; ═══════════════════════════════════════════════════════════════════════════
;; 2. XDG directory layout
;; ═══════════════════════════════════════════════════════════════════════════

(defcustom pro-history-xdg-state-home
  (or (and (getenv "XDG_STATE_HOME") (expand-file-name (getenv "XDG_STATE_HOME")))
      (expand-file-name "~/.local/state"))
  "Base directory for durable state."
  :type 'directory
  :group 'pro-history)

(defcustom pro-history-xdg-cache-home
  (or (and (getenv "XDG_CACHE_HOME") (expand-file-name (getenv "XDG_CACHE_HOME")))
      (expand-file-name "~/.cache"))
  "Base directory for cache/temporary files."
  :type 'directory
  :group 'pro-history)

(defvar pro-history-state-directory
  (expand-file-name "pro-emacs/" pro-history-xdg-state-home)
  "Directory for durable pro-emacs state (backups, savehist, recentf, places, sessions).")

(defvar pro-history-cache-directory
  (expand-file-name "pro-emacs/" pro-history-xdg-cache-home)
  "Directory for pro-emacs cache (auto-save, temp, logs).")

(defvar pro-history-backup-directory
  (expand-file-name "backups/" pro-history-state-directory)
  "Directory where Emacs stores backup files.")

(defvar pro-history-auto-save-directory
  (expand-file-name "auto-save/" pro-history-cache-directory)
  "Directory where Emacs stores auto-save files.")

(defvar pro-history-auto-save-list-directory
  (expand-file-name "auto-save-list/" pro-history-cache-directory)
  "Directory where Emacs stores auto-save-list files.")

(defvar pro-history-session-directory
  (expand-file-name "sessions/" pro-history-state-directory)
  "Directory for session snapshots and pro/session files.")

(defvar pro-history-snapshot-directory
  (expand-file-name "snapshots/" pro-history-state-directory)
  "Directory for layout/window snapshots (quicksave/quickload).")

(defun pro-history-state-file (&rest parts)
  "Return a path under `pro-history-state-directory' joined with PARTS."
  (let ((base pro-history-state-directory))
    (expand-file-name (mapconcat 'identity parts "/") base)))

(defun pro-history-cache-file (&rest parts)
  "Return a path under `pro-history-cache-directory' joined with PARTS."
  (let ((base pro-history-cache-directory))
    (expand-file-name (mapconcat 'identity parts "/") base)))

(defun pro-history-ensure-directories ()
  "Ensure all pro-history directories exist (idempotent)."
  (dolist (d (list pro-history-state-directory
                   pro-history-backup-directory
                   pro-history-session-directory
                   pro-history-snapshot-directory
                   pro-history-cache-directory
                   pro-history-auto-save-directory
                   pro-history-auto-save-list-directory))
    (unless (file-directory-p d)
      (make-directory d t))))

(defun pro-history-describe-paths ()
  "Return alist of important pro-history paths."
  `((state . ,pro-history-state-directory)
    (cache . ,pro-history-cache-directory)
    (backups . ,pro-history-backup-directory)
    (auto-save . ,pro-history-auto-save-directory)
    (auto-save-list . ,pro-history-auto-save-list-directory)
    (sessions . ,pro-history-session-directory)
    (snapshots . ,pro-history-snapshot-directory)))

;; ═══════════════════════════════════════════════════════════════════════════
;; 3. Customization: retention & kill-ring
;; ═══════════════════════════════════════════════════════════════════════════

(defcustom pro-history-backup-retention-days 90
  "Default age in days after which backups are considered for pruning."
  :type 'integer
  :group 'pro-history)

(defcustom pro-history-session-retention-days 365
  "Default age in days after which session snapshots are pruned."
  :type 'integer
  :group 'pro-history)

(defcustom pro-history-max-kill-ring 400
  "Maximum length of kill-ring for pro-history snapshots."
  :type 'integer
  :group 'pro-history)

(defcustom pro-history-enable-undo-tree t
  "If non-nil, enable persistent undo via undo-tree when available."
  :type 'boolean
  :group 'pro-history)

;; ═══════════════════════════════════════════════════════════════════════════
;; 4. Path description helper
;; ═══════════════════════════════════════════════════════════════════════════

(defun pro-history-describe-paths-into-buffer (&optional buffer)
  "Interactively show `pro-history-describe-paths' in BUFFER.
If BUFFER is nil, display in *pro-history-paths* buffer."
  (interactive)
  (let* ((info (pro-history-describe-paths))
         (buf (get-buffer-create (or buffer "*pro-history-paths*"))))
    (with-current-buffer buf
      (setq-local truncate-lines t)
      (erase-buffer)
      (insert (format "pro-history paths (state=%s cache=%s)\n\n" pro-history-state-directory pro-history-cache-directory))
      (dolist (pair info)
        (insert (format "%s: %s\n" (car pair) (cdr pair))))
      (goto-char (point-min)))
    (display-buffer buf)))

;; ═══════════════════════════════════════════════════════════════════════════
;; 5. Pruning helpers
;; ═══════════════════════════════════════════════════════════════════════════

(defun pro-history--files-older-than (dir days)
  "Return list of files under DIR older than DAYS (integer)."
  (let* ((cutoff (float-time (time-subtract (current-time) (days-to-time days)))))
    (when (file-directory-p dir)
      (let (res)
        (dolist (f (directory-files-recursively dir ".*"))
          (when (> cutoff (float-time (nth 5 (file-attributes f))))
            (push f res)))
        res))))

(defun pro-history-prune-backups (&optional days)
  "Prune backup files older than DAYS in `pro-history-backup-directory'.
If DAYS is nil use `pro-history-backup-retention-days'.
Returns list of removed files."
  (interactive "P")
  (let* ((d (or (and days (prefix-numeric-value days)) pro-history-backup-retention-days))
         (files (pro-history--files-older-than pro-history-backup-directory d))
         (removed '()))
    (when (null files)
      (message "pro-history: no backup files older than %d days" d)
      files)
    (dolist (f files)
      (condition-case _err
          (progn (delete-file f) (push f removed))
        (error (message "pro-history: failed to remove %s" f))))
    (when removed (message "pro-history: removed %d backup files" (length removed)))
    removed))

(defun pro-history-prune-sessions (&optional days)
  "Prune session snapshot files older than DAYS from `pro-history-session-directory'.
If DAYS is nil use `pro-history-session-retention-days'. Returns removed files."
  (interactive "P")
  (let* ((d (or (and days (prefix-numeric-value days)) pro-history-session-retention-days))
         (files (pro-history--files-older-than pro-history-session-directory d))
         (removed '()))
    (when (null files)
      (message "pro-history: no session files older than %d days" d)
      files)
    (dolist (f files)
      (condition-case _err
          (progn (delete-file f) (push f removed))
        (error (message "pro-history: failed to remove %s" f))))
    (when removed (message "pro-history: removed %d session files" (length removed)))
    removed))

;; ═══════════════════════════════════════════════════════════════════════════
;; 6. Undo-tree — persistent undo with silent save/load
;; ═══════════════════════════════════════════════════════════════════════════

(defun pro-history--undo-tree-config ()
  "Configure undo-tree: persistent history, visualizer, silent save/load."
  (when (and pro-history-enable-undo-tree (require 'undo-tree nil t))
    (let ((ud-dir (pro-history-state-file "undo")))
      (unless (file-directory-p ud-dir)
        (make-directory ud-dir t))
      (setq undo-tree-auto-save-history t)
      (setq undo-tree-history-directory-alist `((".*" . ,ud-dir)))
      (setq undo-tree-history-overwrite t)
      (setq undo-tree-visualizer-timestamps t)
      (setq undo-tree-visualizer-diff t)
      (when (fboundp 'global-undo-tree-mode)
        (global-undo-tree-mode 1)))

    ;; Silent save: suppress y-or-n-p prompts when saving undo history
    (defun pro-history--undo-tree-save-silently (orig-fun &rest args)
      "Wrap `undo-tree-save-history' to always confirm without prompts."
      (let ((undo-tree-history-overwrite t))
        (condition-case _
            (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t))
                      ((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
              (apply orig-fun args))
          (wrong-number-of-arguments
           (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t))
                     ((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
             (apply orig-fun (list (car args))))))))
    (advice-add 'undo-tree-save-history :around #'pro-history--undo-tree-save-silently)

    ;; Silent load: suppress prompts when restoring undo history
    (defun pro-history--undo-tree-load-silently (orig-fun &rest args)
      "Wrap `undo-tree-load-history' to always confirm without dialogs."
      (condition-case _
          (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t))
                    ((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
            (apply orig-fun args))
        (wrong-number-of-arguments
         (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t))
                   ((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
           (apply orig-fun (list (car args)))))))
    (advice-add 'undo-tree-load-history :around #'pro-history--undo-tree-load-silently)

    ;; Auto-load undo history when a file is opened, auto-save after save
    (defun pro-history--undo-tree-load-and-save ()
      "Load undo history for the current file and arrange auto-save on save.
Runs from `undo-tree-mode-hook'; extracted to a defun so the hook stays
idempotent across `pro/reload-config' reloads (lambdas would accumulate)."
      (when undo-tree-mode
        (when buffer-file-name
          (ignore-errors (undo-tree-load-history)))
        (add-hook 'after-save-hook
                  #'pro-history--undo-tree-save-after-save
                  nil t)))
    (defun pro-history--undo-tree-save-after-save ()
      "Buffer-local `after-save-hook' that saves undo history silently."
      (ignore-errors (undo-tree-save-history nil t)))
    (add-hook 'undo-tree-mode-hook #'pro-history--undo-tree-load-and-save)

    ;; Save undo history for all buffers on exit
    (defun pro-history--save-all-undo-on-exit ()
      "Save undo history for every live buffer that has undo-tree-mode."
      (dolist (buf (buffer-list))
        (with-current-buffer buf
          (when (and (bound-and-true-p undo-tree-mode) buffer-file-name)
            (ignore-errors (undo-tree-save-history nil t))))))
    (add-hook 'kill-emacs-hook #'pro-history--save-all-undo-on-exit)

    ;; Auto-save all modified buffers on exit, no prompts
    (defun pro-history--save-buffers-kill-emacs-silently (orig-fun &optional arg)
      "Wrap `save-buffers-kill-emacs' to skip the yes-or-no prompt."
      (apply orig-fun (list t)))
    (advice-add 'save-buffers-kill-emacs :around #'pro-history--save-buffers-kill-emacs-silently)))

(defun pro-history-clear-undo (&optional confirm)
  "Delete all files under undo history directory. Prompts unless CONFIRM is nil.
Returns list of removed files."
  (interactive "P")
  (let ((d (pro-history-state-file "undo")))
    (unless (file-directory-p d)
      (user-error "pro-history: undo directory missing: %s" d))
    (when (or (not confirm) (y-or-n-p (format "Delete all undo files in %s? " d)))
      (let ((files (directory-files-recursively d ".*")) removed)
        (dolist (f files)
          (condition-case _err
              (when (file-regular-p f) (delete-file f) (push f removed))
            (error (message "pro-history: failed to delete %s" f))))
        (message "pro-history: removed %d undo files" (length removed))
        removed))))

(defun pro-history-clear-current-undo ()
  "Clear undo history for the current buffer only."
  (interactive)
  (when (bound-and-true-p undo-tree-mode)
    (setq undo-tree-stack nil
          undo-tree-redo-stack nil
          buffer-undo-tree nil)
    (message "Undo history cleared for this buffer!"))
  (unless (bound-and-true-p undo-tree-mode)
    (message "undo-tree-mode is not active in this buffer.")))

(defun pro-history-show-undo-files ()
  "Open undo directory in dired if present."
  (interactive)
  (let ((d (pro-history-state-file "undo")))
    (if (file-directory-p d)
        (dired (file-name-as-directory d))
      (message "pro-history: undo directory does not exist: %s" d))))

(defun pro-history-show-undo-file ()
  "Show the persistent undo file path for the current buffer."
  (interactive)
  (if (not buffer-file-name)
      (message "Buffer is not file-backed — persistent undo not available.")
    (let* ((dir (cdr (assoc ".*" undo-tree-history-directory-alist)))
           (name (and dir (concat (file-name-as-directory dir)
                                  (replace-regexp-in-string "[/\\:]" "%" buffer-file-name)))))
      (if (and name (not (string-empty-p name)))
          (message "Undo file: %s" name)
        (message "Could not determine undo file path.")))))

;; ═══════════════════════════════════════════════════════════════════════════
;; 7. Goto last change / last point
;; ═══════════════════════════════════════════════════════════════════════════

(defun pro-history--configure-goto-last-change ()
  "Configure goto-last-change package if available."
  (when (require 'goto-last-change nil t)
    ;; Bindings registered via pro/register-module-keys — not here.
    ))

(defun pro-history--configure-goto-last-point ()
  "Configure goto-last-point package if available."
  (when (require 'goto-last-point nil t)
    (when (fboundp 'goto-last-point-mode)
      (goto-last-point-mode 1))))

;; ═══════════════════════════════════════════════════════════════════════════
;; 8. Eyebrowse — workspace tabs (opt-in, requires eyebrowse package)
;; ═══════════════════════════════════════════════════════════════════════════

(defcustom pro-history-enable-eyebrowse nil
  "If non-nil, enable eyebrowse workspace management when available."
  :type 'boolean
  :group 'pro-history)

(defun pro-history--configure-eyebrowse ()
  "Configure eyebrowse if available and enabled."
  (when (and pro-history-enable-eyebrowse (require 'eyebrowse nil t))
    (when (fboundp 'eyebrowse-mode)
      (eyebrowse-mode 1))))

;; ═══════════════════════════════════════════════════════════════════════════
;; 9. Modified buffers helper
;; ═══════════════════════════════════════════════════════════════════════════

(defun pro-history-show-modified-buffers ()
  "Open ibuffer filtered to modified buffers only."
  (interactive)
  (if (fboundp 'ibuffer)
      (ibuffer nil "*Modified buffers*" '((modified . t)))
    (user-error "ibuffer is not available")))

;; ═══════════════════════════════════════════════════════════════════════════
;; 10. Layout/window snapshots (quicksave / quickload)
;; ═══════════════════════════════════════════════════════════════════════════

(defun pro-history-save-snapshot (&optional label)
  "Save current layout and session as a snapshot.
Saves window configuration to register and session to snapshot directory.
LABEL is a short name (default \"h\")."
  (interactive "sLabel (default 'h'): ")
  (let ((reg (if (string-empty-p label) ?h (aref label 0)))
        (lbl (if (string-empty-p label) "h" label)))
    (pro-history-ensure-directories)
    (window-configuration-to-register reg)
    (when (and (fboundp 'desktop-save) (fboundp 'desktop-save-mode))
      (ignore-errors (desktop-save pro-history-snapshot-directory t)))
    (message "Snapshot (layout + session) saved to register %c and directory %s"
             reg pro-history-snapshot-directory)))

(defun pro-history-restore-snapshot (&optional label)
  "Restore a previously saved layout snapshot.
LABEL is the snapshot name (default \"h\")."
  (interactive "sLabel (default 'h'): ")
  (let ((reg (if (string-empty-p label) ?h (aref label 0)))
        (lbl (if (string-empty-p label) "h" label)))
    (jump-to-register reg)
    (when (and (fboundp 'desktop-read)
               (file-directory-p pro-history-snapshot-directory))
      (ignore-errors (desktop-read pro-history-snapshot-directory)))
    (message "Snapshot restored from register %c" reg)))

(defun pro-history-restore-last-session ()
  "Restore the last desktop session (open all windows/buffers/layout)."
  (interactive)
  (when (fboundp 'desktop-read)
    (desktop-read)
    (message "Last session restored!")))

;; ═══════════════════════════════════════════════════════════════════════════
;; 11. Kill-ring snapshot save/restore
;; ═══════════════════════════════════════════════════════════════════════════

(defvar pro-history-kill-ring-snapshot-file
  (pro-history-state-file "kill-ring.el")
  "File used to persist a snapshot of `kill-ring'.")

(defun pro-history--kill-ring-file-content (ring)
  "Return RING serialised as a readable Lisp expression."
  (prin1-to-string ring))

(defun pro-history-save-kill-ring-snapshot (&optional file)
  "Persist the current `kill-ring' to FILE.
If FILE is nil, use `pro-history-kill-ring-snapshot-file'.
Returns the written file name."
  (interactive)
  (let ((target (or file pro-history-kill-ring-snapshot-file)))
    (pro-history-ensure-directories)
    (with-temp-file target
      (prin1 kill-ring (current-buffer)))
    (message "Kill-ring saved: %s" target)
    target))

(defun pro-history-load-kill-ring-snapshot (&optional file)
  "Load `kill-ring' from FILE.
If FILE is nil, use `pro-history-kill-ring-snapshot-file'.
Returns non-nil when a snapshot was loaded."
  (interactive)
  (let ((target (or file pro-history-kill-ring-snapshot-file)))
    (when (file-readable-p target)
      (let ((new-kill (with-temp-buffer
                        (insert-file-contents target)
                        (goto-char (point-min))
                        (read (current-buffer)))))
        (when (listp new-kill)
          (setq kill-ring (cl-subseq new-kill 0 (min (length new-kill) kill-ring-max)))))
      (message "Kill-ring restored from: %s" target)
      t)))

(defun pro-history-clear-kill-ring-snapshot (&optional file)
  "Delete FILE used for the `kill-ring' snapshot.
If FILE is nil, use `pro-history-kill-ring-snapshot-file'."
  (interactive)
  (let ((target (or file pro-history-kill-ring-snapshot-file)))
    (when (file-exists-p target)
      (delete-file target)
      t)))

;; ═══════════════════════════════════════════════════════════════════════════
;; 12. Time Machine (undo-tree visualizer)
;; ═══════════════════════════════════════════════════════════════════════════

(defun pro-history-time-machine ()
  "Open the undo tree visualizer (Time Machine) for the current buffer."
  (interactive)
  (cond
   ((bound-and-true-p undo-tree-mode)
    (undo-tree-visualize))
   ((fboundp 'vundo)
    (vundo))
    (t (user-error "undo-tree-mode or vundo is not available!"))))

(defun pro-history-undo ()
  "Undo using undo-tree when available, otherwise Emacs built-in undo."
  (interactive)
  (if (fboundp 'undo-tree-undo)
      (undo-tree-undo)
    (call-interactively #'undo)))

(defun pro-history-redo ()
  "Redo using undo-tree when available, otherwise Emacs built-in redo."
  (interactive)
  (cond
   ((fboundp 'undo-tree-redo) (undo-tree-redo))
   ((fboundp 'undo-redo) (call-interactively #'undo-redo))
   (t (user-error "Redo is not available in this Emacs"))))

;; ═══════════════════════════════════════════════════════════════════════════
;; 13. Transient menu
;; ═══════════════════════════════════════════════════════════════════════════

;; Declare transient prefix if transient is available.
;; We use autoload-like pattern: define only when transient is present.
(with-eval-after-load 'transient
  (transient-define-prefix pro-history-transient ()
    "Time Machine commands: undo, redo, layout, kill-ring, snapshots."
    ["Undo / Redo"
     ("u" "Time Machine (undo-tree)"    pro-history-time-machine)
     ("e" "Last edit"                   goto-last-change)
     ("j" "Previous cursor"             goto-last-point)
     ("b" "Modified buffers"            pro-history-show-modified-buffers)
     ("s" "Restore last session"        pro-history-restore-last-session)]
    ["Cleanup"
     ("U" "Clear undo (current buffer)" pro-history-clear-current-undo)
     ("F" "Delete all undo files"       pro-history-clear-undo)]
    ["Snapshots"
     ("q" "Save snapshot"              pro-history-save-snapshot)
     ("Q" "Restore snapshot"           pro-history-restore-snapshot)]
    ["Kill-ring"
     ("k" "Save kill-ring"             pro-history-save-kill-ring-snapshot)
     ("K" "Restore kill-ring"          pro-history-load-kill-ring-snapshot)]
    ["Other"
     ("h" "Help / Eco Help"            pro-history-eco-help)
     ("p" "Show paths"                 pro-history-describe-paths-into-buffer)]))

(defun pro-history-eco-help ()
  "Show a brief help/guide for pro-history features."
  (interactive)
  (with-help-window "*pro-history: Help*"
    (princ
     "==== Emacs pro-history: your personal Time Machine ====\n\n\
Every step in Emacs can be undone, redone, restored, and saved forever.\n\n\
Available at any time:\n\
  • Undo-tree: undo/redo changes as a tree — like the best IDEs!\n\
  • Goto last change / last point: jump to your last edit instantly.\n\
  • Kill-ring snapshots: persist your clipboard history across sessions.\n\
  • Layout snapshots: save and restore window configurations.\n\
  • Session restore: bring back all windows/buffers/layout.\n\
  • Backup/auto-save policies: clean state in XDG directories.\n\
  • Pruning: auto-cleanup of old backups and sessions.\n\n\
Transient menu: M-x pro-history-transient RET\n\
========================================================\n\
pro-history — part of pro-nix")))

;; ═══════════════════════════════════════════════════════════════════════════
;; 14. Configure backup/auto-save/savehist/recentf/saveplace/desktop
;; ═══════════════════════════════════════════════════════════════════════════

(defun pro-history-configure-backups ()
  "Apply backup-directory-alist and related settings."
  (setq backup-directory-alist `((".*" . ,pro-history-backup-directory)))
  (setq make-backup-files t)
  (setq backup-by-copying t)
  (setq version-control t)
  (setq delete-old-versions t)
  (setq kept-new-versions 25)
  (setq kept-old-versions 5)
  (setq vc-make-backup-files t)
  (setq create-lockfiles nil))

(defun pro-history-configure-auto-save ()
  "Apply auto-save policy: send auto-saves to cache directory."
  (setq auto-save-default t)
  (setq auto-save-timeout 20)
  (setq auto-save-interval 200)
  (setq auto-save-file-name-transforms
        `((".*" ,(expand-file-name "\\1" (file-name-as-directory pro-history-auto-save-directory)) t)))
  (setq auto-save-list-file-prefix
        (expand-file-name ".saves-" pro-history-auto-save-list-directory)))

(defun pro-history-configure-savehist ()
  "Configure savehist to use state directory."
  (ignore-errors (require 'savehist))
  (setq savehist-file (pro-history-state-file "savehist.el"))
  (setq savehist-autosave-interval nil)
  (setq savehist-additional-variables
        '(search-ring regexp-search-ring extended-command-history
                      projectile-project-command-history kill-ring compile-command
                      file-name-history shell-command-history
                      consult--path-history consult--grep-history consult--find-history
                      consult--man-history consult--line-history consult--line-multi-history
                      consult--theme-history consult--minor-mode-menu-history
                      consult--buffer-history))
  (when (fboundp 'savehist-mode)
    (savehist-mode 1)))

(defun pro-history-configure-recentf ()
  "Configure recentf to use state directory and exclude pro internals."
  (ignore-errors (require 'recentf))
  (setq recentf-save-file (pro-history-state-file "recentf.el"))
  (setq recentf-max-saved-items 500)
  (setq recentf-auto-cleanup 'never)
  (setq recentf-exclude
        `(,pro-history-state-directory
          ,pro-history-cache-directory
          "/\\.git/"
          "/\\.emacs\\.d/elpa/"
          "-autoloads\\.el\\'"
          "\\.elc\\'"
          "\\.eln\\'"
          "/TAGS\\'"))
  ;; Ensure recentf-mode is on (but don't crash if it's not available)
  (ignore-errors (recentf-mode 1)))

(defun pro-history-configure-desktop-and-session ()
  "Configure desktop and session management."
  (ignore-errors (require 'desktop))
  (setq desktop-save t
        desktop-restore-frames t
        desktop-files-not-to-save (concat "^$" (regexp-opt '("TAGS" "core" "dired"))))
  (when (and (fboundp 'desktop-save) (fboundp 'add-hook))
    (add-hook 'kill-emacs-hook #'pro-history-save-desktop-silently))
  (message "Desktop is not restored automatically. Restore with M-x pro-history-restore-last-session")
  ;; Winner mode for window configuration undo/redo
  (when (fboundp 'winner-mode)
    (winner-mode 1)))

(defun pro-history-save-desktop-silently ()
  "Save the current desktop without prompting."
  (ignore-errors
    (when (fboundp 'desktop-save)
      (desktop-save nil t))))

(defun pro-history-configure-saveplace ()
  "Configure save-place to use state directory."
  (ignore-errors (require 'saveplace))
  (setq save-place-file (pro-history-state-file "places.el"))
  (when (fboundp 'save-place-mode)
    (save-place-mode 1)))

;; ═══════════════════════════════════════════════════════════════════════════
;; 15. Kill-ring base settings
;; ═══════════════════════════════════════════════════════════════════════════

(defun pro-history-configure-kill-ring ()
  "Apply kill-ring base settings."
  (setq kill-ring-max pro-history-max-kill-ring
        save-interprogram-paste-before-kill t
        yank-pop-change-selection t
        x-select-enable-primary t))

;; ═══════════════════════════════════════════════════════════════════════════
;; 16. Top-level initializer
;; ═══════════════════════════════════════════════════════════════════════════

(defun pro-history-initialize ()
  "Initialize pro-history: create dirs, apply policies, enable undo-tree, load kill-ring."
  (pro-history-ensure-directories)
  (pro-history-configure-backups)
  (pro-history-configure-auto-save)
  (pro-history-configure-savehist)
  (pro-history-configure-recentf)
  (pro-history-configure-saveplace)
  (pro-history-configure-desktop-and-session)
  (pro-history-configure-kill-ring)

  ;; Undo-tree with silent save/load
  (ignore-errors (pro-history--undo-tree-config))

  ;; Goto last change / last point (opt-in, no error if not installed)
  (ignore-errors (pro-history--configure-goto-last-change))
  (ignore-errors (pro-history--configure-goto-last-point))

  ;; Eyebrowse (opt-in)
  (ignore-errors (pro-history--configure-eyebrowse))

  ;; Defensive: ensure we do not add data dirs to load-path
  (when (member pro-history-state-directory load-path)
    (setq load-path (remove pro-history-state-directory load-path)))
  (when (member pro-history-cache-directory load-path)
    (setq load-path (remove pro-history-cache-directory load-path)))

  ;; Restore kill-ring snapshot if present
  (when (file-readable-p pro-history-kill-ring-snapshot-file)
    (ignore-errors (pro-history-load-kill-ring-snapshot)))

  (message "pro-history: initialized (state=%s cache=%s)" pro-history-state-directory pro-history-cache-directory))

;; ═══════════════════════════════════════════════════════════════════════════
;; 17. Register suggested keys (after pro-keys is loaded)
;; ═══════════════════════════════════════════════════════════════════════════

(with-eval-after-load 'pro-keys
  (condition-case _err
      (when (fboundp 'pro/register-module-keys)
        (pro/register-module-keys 'history
                                  '(("C-c u"   . pro-history-time-machine)
                                    ("C-_"     . pro-history-undo)
                                    ("M-_"     . pro-history-redo)
                                    ("C-z"     . pro-history-undo)
                                    ("C-M-z"   . pro-history-redo)
                                    ("C-c z"   . pro-history-time-machine)
                                    ("C-c C-," . goto-last-change-reverse)
                                    ("C-c ."   . goto-last-change)
                                    ("C-c ,"   . goto-last-change-reverse)
                                    ("<XF86Back>"    . winner-undo)
                                    ("<XF86Forward>" . winner-redo)
                                    ("C-c M-h" . pro-history-transient))))
    (error (message "[pro-history] failed to register suggested keys"))))

;; ═══════════════════════════════════════════════════════════════════════════
;; Initialize at load
;; ═══════════════════════════════════════════════════════════════════════════

(pro-history-initialize)

(provide 'pro-history)

;;; pro-history.el ends here
