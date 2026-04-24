;;; project.el --- проекты -*- lexical-binding: t; -*-

;; Этот модуль связывает проектный корень, поиск и git в один рабочий цикл.

(require 'subr-x)

(let* ((module-dir (file-name-directory (or load-file-name buffer-file-name)))
       (search-path (delete module-dir (copy-sequence load-path)))
       (project-library (locate-library "project" nil search-path)))
  (when project-library
    (load project-library nil t)))

(defvar pro-project-switch-commands '((pro-project-find-file "Find file")
                                      (pro-project-find-dir "Find dir")
                                      (pro-project-switch-to-buffer "Buffer")
                                      (pro-project-open-dired "Dired"))
  "Команды проекта в стиле PRO.")

(defun pro-project-root ()
  "Return project root.

Prefer projectile when available (projectile-project-root), otherwise use
the built-in project.el's project-current/project-root. Return nil when no
project can be determined. This makes the project layer adaptive to either
backend." 
  (cond
   ;; Projectile preferred for its richer UX when installed
   ((and (fboundp 'projectile-project-root)
         (projectile-project-root))
    (projectile-project-root))
   ;; Fallback to project.el
   ((and (fboundp 'project-current))
    (when-let ((project (project-current)))
      (project-root project)))
   (t nil)))

(defun pro-project-ripgrep ()
  "Искать в текущем проекте через Consult."
  (interactive)
  (let ((root (or (pro-project-root) default-directory)))
    (cond
     ;; If projectile is present prefer consult-projectile or projectile's helpers
     ((and (fboundp 'projectile-project-root) (fboundp 'consult-ripgrep) (fboundp 'projectile-project-root))
      (consult-ripgrep root))
     ;; Standard consult-ripgrep
     ((and (or (pro--package-provided-p 'consult) (require 'consult nil t)) (fboundp 'consult-ripgrep))
      (consult-ripgrep root))
     (t
      (pro-compat--notify-once "consult" "consult-ripgrep missing — fallback to grep")
      (let ((default-directory root))
        (call-interactively #'grep))))))

(defun pro-project-find-file ()
  "Открыть файл внутри текущего проекта."
  (interactive)
  (let ((root (or (pro-project-root) default-directory)))
    ;; Prefer consult-find when available; when fd is missing but rg is present,
    ;; prefer consult-ripgrep as a fallback for fast file listing.
    (cond
     ((and (fboundp 'projectile-project-root) (fboundp 'projectile-find-file))
      ;; If projectile is present delegate to it — it may use caching/indexing.
      (let ((default-directory root))
        (call-interactively #'projectile-find-file)))
     ((and (or (pro--package-provided-p 'consult) (require 'consult nil t)) (fboundp 'consult-find))
      (consult-find root))
     ((and (fboundp 'consult-ripgrep) (executable-find "rg"))
      (consult-ripgrep root))
     (t
      (pro-compat--notify-once "consult" "consult-find missing — fallback to find-file")
      (let ((default-directory root))
        (call-interactively #'find-file))))))

(defun pro-project-switch-buffer ()
  "Переключить буфер внутри проекта."
  (interactive)
  (if (or (pro--package-provided-p 'consult) (pro-packages--maybe-install 'consult t) (require 'consult nil t))
      (consult-buffer)
    (pro-compat--notify-once "consult" "consult-buffer missing — fallback to switch-to-buffer")
    (call-interactively #'switch-to-buffer)))

(defun pro-project-open-dired ()
  "Открыть dired в корне проекта."
  (interactive)
  (dired (or (pro-project-root) default-directory)))

(with-eval-after-load 'project
  (setq project-switch-commands pro-project-switch-commands))

;; If projectile is loaded, ensure our pending bindings and integrations are
;; aware and prefer projectile UI where appropriate.
(with-eval-after-load 'projectile
  ;; prefer projectile's completion helpers if available
  (when (fboundp 'projectile-mode)
    (projectile-mode 1)
  ;; If consult-projectile is available, ensure it's loaded for better UX
  (when (pro--package-provided-p 'consult-projectile)
    (ignore (require 'consult-projectile nil t))))

(provide 'pro-project)
