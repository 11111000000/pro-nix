;;; project.el --- проекты -*- lexical-binding: t; -*-

;; Этот модуль связывает проектный корень, поиск и git в один рабочий цикл.

(require 'subr-x)

(when (require 'project nil t)
  (setq project-switch-commands '((project-find-file "Find file")
                                  (project-find-dir "Find dir")
                                  (project-switch-to-buffer "Buffer")
                                  (project-dired "Dired"))))

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

(provide 'project)
