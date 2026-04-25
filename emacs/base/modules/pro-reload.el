;;; pro-reload.el --- Soft reload helpers for pro-nix -*- lexical-binding: t; -*-
;; Простые и безопасные функции для перезагрузки модулей и фоновых обновлений.

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

(provide 'pro-reload)

;;; pro-reload.el ends here
