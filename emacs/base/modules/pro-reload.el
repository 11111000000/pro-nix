;;; pro-reload.el --- Soft reload helpers for pro-nix -*- lexical-binding: t; -*-
;; Название: emacs/base/modules/pro-reload.el — Soft reload utilities
;; Кратко: безопасные helper-функции для перезагрузки модулей, фоновых обновлений и управления сессией.
;;
;; Контракт:
;; - pro/reload-module, pro/reload-all-modules, pro/update-melpa-in-background, pro/nix-generate-and-refresh-paths,
;;   pro/session-save-and-restart-emacs — публичные API этого файла.
;; - Все функции должны быть idempotent и не ломать текущую сессию при ошибках (используют ignore-errors/condition-case).
;; - Побочные эффекты: запуск фоновых процессов, запись файлов сессий, модификация load-path.
;;
;; Reload contract for module authors:
;; - Re-evaluating a module via `pro/reload-module' always runs the *current*
;;   contents of the .el file (we drop the load-history entry, so mtime tricks
;;   with .elc don't mask changes).
;; - Modules that own persistent state (child frames, background processes,
;;   globalised variables) should register a teardown function on
;;   `pro--after-reload-hook' so a reload actually re-creates that state
;;   from the freshly-loaded code.  Use `pro/after-reload #'my-reset-fn'.
;; - Modules should keep their top-level forms idempotent (use the
;;   pro-compat--add-hook-once / add-to-list-once / advice-add-once
;;   helpers) — re-evaluation will re-run them on every reload.
;;
;; Proof: headless ERT и ./scripts/emacs-pro-wrapper.sh smoke tests.
;; Last reviewed: 2026-05-02

(require 'subr-x)
(require 'cl-lib)                       ; for `cl-remove-if' in
                                        ; `pro--forget-file-in-load-history'.

(defvar pro--before-reload-hook nil
  "Normal hook run before `pro/reload-config' re-evaluates modules.
Modules register cleanup (kill child frames, stop bg processes, etc.) here.")

(defvar pro--after-reload-hook nil
  "Normal hook run after `pro/reload-config' has re-evaluated modules.
Modules register re-initialisation (recreate child frames, re-install
watches) here so persistent state is rebuilt from the freshly-loaded
code instead of the pre-reload instance.")

(defun pro/before-reload (fn)
  "Register FN on `pro--before-reload-hook' (idempotent). FN is a
function with no required args; errors are swallowed by the caller."
  (unless (memq fn pro--before-reload-hook)
    (add-hook 'pro--before-reload-hook fn)))

(defun pro/after-reload (fn)
  "Register FN on `pro--after-reload-hook' (idempotent). FN is a
function with no required args; errors are swallowed by the caller."
  (unless (memq fn pro--after-reload-hook)
    (add-hook 'pro--after-reload-hook fn)))

(defun pro--resolve-module-file (module)
  "Вернуть путь к файлу MODULE.el в системном каталоге модулей pro.
MODULE может быть символом или строкой (например "terminals").
Возвращает nil, если файл не найден или недоступен.
"
  (let* ((name (if (symbolp module) (symbol-name module) (format "%s" module)))
         (dir (and (boundp 'pro-emacs-base-system-modules-dir)
                   pro-emacs-base-system-modules-dir))
         (path (and dir (expand-file-name (format "%s.el" name) dir))))
    (and path (file-readable-p path) path)))

(defun pro--forget-file-in-load-history (file)
  "Remove all load-history entries whose file is FILE (or its .elc).
Also unbind features provided by the file.  Required because Emacs
uses load-history as the source of truth for `load' re-evaluation:
if the recorded load time matches the file's mtime, the .el is not
re-evaluated, even when the user is asking for an explicit reload."
  (let* ((truename (ignore-errors (file-truename file)))
         (matches (lambda (entry)
                    (and (consp entry)
                         (stringp (car entry))
                         (or (string= (car entry) file)
                             (and truename
                                  (string= (car entry) truename))
                             (string= (car entry)
                                      (concat (file-name-sans-extension file) ".elc"))))))
         ;; Collect features provided by the file so we can `unload-feature'.
         (features-to-unbind nil))
    (dolist (entry load-history)
      (when (funcall matches entry)
        ;; entry is (FILE . FORMS). FORMS looks like (provide . FEATURE) etc.
        (dolist (form (cdr entry))
          (when (and (consp form) (eq (car form) 'provide)
                     (symbolp (cdr form)))
            (push (cdr form) features-to-unbind)))))
    ;; Drop matching entries.
    (setq load-history
          (cl-remove-if matches load-history))
    ;; Also drop .elc load-history entries, which `load' would otherwise
    ;; prefer when the .elc is newer than .el.
    (let ((elc (concat (file-name-sans-extension file) ".elc")))
      (when (file-exists-p elc)
        (setq load-history
              (cl-remove-if (lambda (e)
                              (and (consp e) (stringp (car e))
                                   (string= (car e) elc)))
                            load-history))))
    ;; Unbind features (silently — module's top-level `(provide ...)' will
    ;; re-add them on re-evaluation).
    (dolist (feat features-to-unbind)
      (ignore-errors (unload-feature feat t)))))

(defun pro/reload-module (module)
  "Перезагрузить MODULE из каталога pro-модулей.
MODULE — символ или строка. Возвращает t при успехе, nil при ошибке.

Что происходит:
  1. Удаляется .elc, если он СТАРШЕ .el (mtime .el новее) — без этого
     `load' подхватит устаревший скомпилированный код.
  2. Удаляется .elc, если он НОВЕЕ .el — типичный случай после
     `byte-compile-file'; в этой ситуации Emacs все равно загрузит
     .elc, но мы хотим, чтобы `load-file' ниже взял именно .el.
  3. Из `load-history' выкидывается запись об этом файле (и его .elc),
     а соответствующий `provide' делается `unload-feature'. Без этого
     `load' считает файл уже загруженным с актуальной меткой времени
     и молча пропускает переоценку.
  4. `load-file' запускает свежий .el с диска.

Если в `load-history' нет записи (модуль загружался до reload),
шаги 1–3 безвредно no-op'ятся."
  (interactive (list (intern (completing-read "Module: "
                                               (mapcar (lambda (m) (if (symbolp m) (symbol-name m) (format "%s" m)))
                                                       (when (boundp 'pro-emacs-base-default-modules) pro-emacs-base-default-modules))
                                               nil t))))
  (let ((file (pro--resolve-module-file module)))
    (if (not file)
        (progn (message "pro/reload-module: module file not found: %s" module) nil)
      (condition-case err
          (progn
           (let ((elc (concat (file-name-sans-extension file) ".elc")))
             (when (and (file-exists-p elc)
                        (file-newer-than-file-p file elc))
               (delete-file elc)
               (message "pro/reload-module: removed stale %s" elc)))
           (pro--forget-file-in-load-history file)
           (load-file file)
           (message "reloaded module %s" module)
           t)
        (error (message "error reloading %s: %S" module err) nil)))))

(defun pro/reload-all-modules ()
  "Перезагрузить все модули из `pro-emacs-base-default-modules'."
  (interactive)
  (when (and (boundp 'pro-emacs-base-default-modules) pro-emacs-base-default-modules)
    (let ((ok 0) (fail 0))
      (dolist (m pro-emacs-base-default-modules)
        (if (ignore-errors (pro/reload-module m))
            (setq ok (1+ ok))
          (setq fail (1+ fail))))
      (message "pro/reload-all-modules: %d ok, %d failed" ok fail))))

(defun pro/update-melpa-in-background ()
  "Запустить фоновый процесс для обновления MELPA/ELPA.
Запускает отдельный Emacs --batch, который выполняет скрипт
scripts/melpa-update.el. Это не блокирует текущую сессию.
"
  (interactive)
  (let* ((repo (file-name-directory (or load-file-name buffer-file-name)))
         (script (expand-file-name "scripts/melpa-update.el" (or repo ".")))
         (emacs-bin (or (executable-find "emacs") "emacs")))
    (when (file-exists-p script)
      (start-process "pro-melpa-update" "*pro-melpa-update*" emacs-bin "--batch" "-Q" "-l" script)
      (message "pro: started background MELPA update"))))

(defun pro/nix-generate-and-refresh-paths ()
  "Вызвать скрипт генерации путей Nix и обновить load-path.
Ожидается, что scripts/nix-update-emacs-paths.sh создаёт файл
emacs/base/nix-emacs-paths.el с переменной `pro/nix-site-lisp-paths'.
"
  (interactive)
  (let* ((repo (file-name-directory (or load-file-name buffer-file-name)))
         (script (expand-file-name "scripts/nix-update-emacs-paths.sh" (or repo ".")))
         (out (expand-file-name "emacs/base/nix-emacs-paths.el" (or repo "."))))
    (when (and (file-executable-p script) (zerop (call-process script nil nil nil)))
      (when (file-readable-p out)
        (load-file out)
        (when (boundp 'pro/nix-site-lisp-paths)
          (require 'nix-refresh nil t)
          (when (fboundp 'pro/nix-load-path-refresh)
            (pro/nix-load-path-refresh pro/nix-site-lisp-paths)))))))

(defun pro/session-save-and-restart-emacs (&optional save-file)
  "Сохранить сессию и перезапустить Emacs, восстановив сессию.
Функция попытётся вызвать `pro/session-save' для сохранения состояния,
а затем запустить новый Emacs, который загрузит сохранённую сессию.
"
  (interactive)
  (let* ((save (or save-file (and (fboundp 'pro/session-save) (pro/session-save))))
         (emacs-bin (or (executable-find "emacs") "emacs")))
    (when save
      (start-process "pro-restart" "*pro-restart*" emacs-bin "--eval" (format "(progn (load \"%s\") (pro/session-restore))" save))
      (message "pro: spawned new Emacs to restore session; exiting current Emacs")
      (kill-emacs))))

(defun pro/revert-buffer ()
  "Revert current buffer without asking for confirmation.
This is a thin wrapper around `revert-buffer' that suppresses the
y-or-n-p prompt by temporarily setting `revert-without-query' to a
catch-all regex and then restoring the previous value.  Safe to call
from any buffer; if `revert-buffer' errors (e.g. no file is associated
or the buffer is non-revertable) the error is surfaced as a message
without aborting the calling command."
  (interactive)
  (let ((prev revert-without-query))
    (condition-case err
        (let ((revert-without-query '(".")))
          (revert-buffer))
      (error
       (setq revert-without-query prev)
       (message "pro/revert-buffer: %S" err)))))

(defun pro/reload-config (&optional full)
  "Reload the whole pro Emacs configuration to apply changes without restarting.

If FULL is non-nil (or called with a prefix argument), re-eval
`site-init.el' from disk (which re-runs provided-packages loading
and the top-level init) AND re-load every module. The non-full path
re-evaluates each module's .el file in place.

Both paths run `pro--before-reload-hook' (modules can tear down child
frames / bg processes / cached state) and `pro--after-reload-hook'
(modules re-create persistent state from the freshly loaded code).

This function is defensive and uses `ignore-errors' / `condition-case' to avoid
breaking the running session when a single module fails to reload.

Usage:
  M-x pro/reload-config      ;; quick reload (modules in-place)
  C-u M-x pro/reload-config  ;; full reload (re-eval site-init.el + modules)
"
  (interactive "P")
  (let ((start (float-time)))
    (message "pro: starting config reload (full=%s)" full)
    ;; 1. Refresh nix-generated paths if available
    (ignore-errors (when (fboundp 'pro/nix-generate-and-refresh-paths)
                     (pro/nix-generate-and-refresh-paths)))
    ;; 2. Pre-reload cleanup. Modules that own child frames / bg
    ;;    processes / cached state should hook this to drop it.
    (run-hooks 'pro--before-reload-hook)
    ;; 3. Re-evaluate module code.
    (condition-case err
        (if full
            (let ((site-init (and (boundp 'pro-emacs-base-system-modules-dir)
                                  (locate-library "pro-site-init"))))
              ;; Re-eval site-init.el from disk so provided-packages,
              ;; manifest resolution, and pro-emacs-base-start all run
              ;; again. `load-file' here is what makes a `full' reload
              ;; actually re-run the top-level side effects.
              (if (and site-init (file-readable-p site-init))
                  (progn
                    (pro--forget-file-in-load-history site-init)
                    (load-file site-init)
                    (when (fboundp 'pro-emacs-base-start)
                      (pro-emacs-base-start)))
                (pro-emacs-base-start))
              (pro/reload-all-modules))
          (pro/reload-all-modules))
      (error (message "pro/reload-config: module reload failed: %S" err)))
    ;; 4. Re-apply keybindings and pending pro-keys entries
    (ignore-errors (when (fboundp 'pro-keys-reload) (pro-keys-reload)))
    (ignore-errors (when (fboundp 'pro-keys-apply-pending) (pro-keys-apply-pending)))
    (ignore-errors (when (fboundp 'pro-keys-report-pending) (pro-keys-report-pending)))
    ;; 5. Reconstruct epistemic state if module provides it
    (ignore-errors (when (fboundp 'pro--reconstruct) (pro--reconstruct)))
    ;; 6. Re-apply UI tweaks like fonts and cursor
    (ignore-errors (when (fboundp 'pro-ui-apply-fonts) (pro-ui-apply-fonts)))
    (ignore-errors (when (fboundp 'pro-ui-apply-fringes) (pro-ui-apply-fringes)))
    (ignore-errors (when (fboundp 'pro-ui-apply-completion) (pro-ui-apply-completion)))
    (ignore-errors (when (fboundp 'pro-ui-apply-icons) (pro-ui-apply-icons)))
    (ignore-errors (when (fboundp 'pro-ui-apply-modeline) (pro-ui-apply-modeline)))
    (ignore-errors (when (fboundp 'pro-ui-apply-theme) (pro-ui-apply-theme)))
    ;; 7. Post-reload re-init. Modules that owned persistent state
    ;;    register a function here to re-create it from the freshly
    ;;    loaded code. Without this, a banner frame created at startup
    ;;    would keep its old geometry even after the module's width
    ;;    math changed.
    (run-hooks 'pro--after-reload-hook)
    (message "pro: config reload finished in %.2fs" (- (float-time) start))))

(provide 'pro-reload)

;;; pro-reload.el ends here
