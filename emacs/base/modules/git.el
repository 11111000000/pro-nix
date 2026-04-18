;;; git.el --- Git workflow -*- lexical-binding: t; -*-

;; Этот модуль держит git-работу короткой: статус, обзор и переход в репозиторий.

(require 'subr-x)

(defun pro-git-status ()
  "Открыть статус репозитория."
  (interactive)
  (when (require 'magit nil t)
    (magit-status (or (and (fboundp 'pro-project-root) (pro-project-root)) default-directory))))

(provide 'git)
