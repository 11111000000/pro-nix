;;; git.el --- Git workflow -*- lexical-binding: t; -*-

;; Этот модуль держит git-работу короткой: статус, обзор и переход в репозиторий.

(require 'subr-x)

(defun pro-git-status ()
  "Открыть статус репозитория."
  (interactive)
  (when (or (pro--package-provided-p 'magit) (require 'magit nil t))
    (let ((root (or (and (fboundp 'pro-project-root) (pro-project-root)) default-directory)))
      (magit-status root))))

(defun pro-git-log-current ()
  "Показать лог текущего репозитория."
  (interactive)
  (when (require 'magit nil t)
    (magit-log-current)))

(defun pro-git-dispatch ()
  "Открыть магитовский диспетчер."
  (interactive)
  (when (or (pro--package-provided-p 'magit) (require 'magit nil t))
    (magit-dispatch)))

(provide 'git)
