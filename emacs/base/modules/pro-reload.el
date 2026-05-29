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
;; Proof: headless ERT и ./scripts/emacs-pro-wrapper.sh smoke tests.
;; Last reviewed: 2026-05-02

(require 'subr-x)

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

(defun pro/reload-module (module)
  "Перезагрузить MODULE из каталога pro-модулей.
MODULE — символ или строка. Возвращает t при успехе, nil при ошибке.
" 
  (interactive (list (intern (completing-read "Module: "
                                               (mapcar (lambda (m) (if (symbolp m) (symbol-name m) (format "%s" m)))
                                                       (when (boundp 'pro-emacs-base-default-modules) pro-emacs-base-default-modules))
                                               nil t))))
  (let ((file (pro--resolve-module-file module)))
    (if (not file)
        (progn (message "pro/reload-module: module file not found: %s" module) nil)
      (condition-case err
          (progn (load-file file) (message "reloaded module %s" module) t)
        (error (message "error reloading %s: %S" module err) nil)))))

(defun pro/reload-all-modules ()
  "Перезагрузить все модули из `pro-emacs-base-default-modules'."
  (interactive)
  (when (and (boundp 'pro-emacs-base-default-modules) pro-emacs-base-default-modules)
    (dolist (m pro-emacs-base-default-modules)
      (ignore-errors (pro/reload-module m)))))

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

(defun pro/reload-config (&optional full)
  "Reload the whole pro Emacs configuration to apply changes without restarting.

If FULL is non-nil (or called with a prefix argument), attempt a more thorough
reload which calls `pro-emacs-base-start' to re-resolve the manifest and
re-load site initialization. The non-full path reloads individual modules and
re-applies auxiliary state (keys, fonts, epistemology) — typically sufficient
after a `just switch'.

This function is defensive and uses `ignore-errors' / `condition-case' to avoid
breaking the running session when a single module fails to reload.

Usage:
  M-x pro/reload-config      ;; quick reload
  C-u M-x pro/reload-config  ;; full reload (re-run site init)
"
  (interactive "P")
  (message "pro: starting config reload (full=%s)" full)
  ;; Refresh nix-generated paths if available
  (ignore-errors (when (fboundp 'pro/nix-generate-and-refresh-paths)
                   (pro/nix-generate-and-refresh-paths)))
  ;; Either do a full site init or reload modules individually
  (if full
      (condition-case err
          (pro-emacs-base-start)
        (error (message "pro/reload-config: pro-emacs-base-start failed: %S" err)))
    (pro/reload-all-modules))
  ;; Re-apply keybindings and pending pro-keys entries
  (ignore-errors (when (fboundp 'pro-keys-reload) (pro-keys-reload)))
  (ignore-errors (when (fboundp 'pro-keys-apply-pending) (pro-keys-apply-pending)))
  (ignore-errors (when (fboundp 'pro-keys-report-pending) (pro-keys-report-pending)))
  ;; Reconstruct epistemic state if module provides it
  (ignore-errors (when (fboundp 'pro--reconstruct) (pro--reconstruct)))
  ;; Re-apply UI tweaks like fonts and cursor
  (ignore-errors (when (fboundp 'pro-ui-apply-fonts) (pro-ui-apply-fonts)))
  (ignore-errors (when (fboundp 'pro-ui-apply-completion) (pro-ui-apply-completion)))
  (ignore-errors (when (fboundp 'pro-ui-apply-icons) (pro-ui-apply-icons)))
  (message "pro: config reload finished"))

(provide 'pro-reload)

;;; pro-reload.el ends here
