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
  "Вернуть корень текущего проекта или nil."
  (when (fboundp 'project-current)
    (when-let ((project (project-current)))
      (project-root project))))

(defun pro-project-ripgrep ()
  "Искать в текущем проекте через Consult."
  (interactive)
  (when (require 'consult nil t)
    (consult-ripgrep (or (pro-project-root) default-directory))))

(defun pro-project-find-file ()
  "Открыть файл внутри текущего проекта."
  (interactive)
  (when (require 'consult nil t)
    (consult-find (or (pro-project-root) default-directory))))

(defun pro-project-switch-buffer ()
  "Переключить буфер внутри проекта."
  (interactive)
  (when (require 'consult nil t)
    (consult-buffer)))

(defun pro-project-open-dired ()
  "Открыть dired в корне проекта."
  (interactive)
  (dired (or (pro-project-root) default-directory)))

(with-eval-after-load 'project
  (setq project-switch-commands pro-project-switch-commands))

(provide 'pro-project)
