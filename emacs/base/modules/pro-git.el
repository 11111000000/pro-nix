;; Русский: комментарии и пояснения оформлены в учебном стиле (пояснения и примеры)
;;; git.el --- Git workflow -*- lexical-binding: t; -*-

;; Этот модуль держит git-работу короткой: статус, обзор и переход в репозиторий.

(require 'subr-x)

(defun pro-git-status ()
  "Открыть статус репозитория."
  (interactive)
(when (or (pro--package-provided-p 'magit) (pro-packages--maybe-install 'magit t) (require 'magit nil t))
    ;; Guard magit-status in case package isn't fully available at init time.
    (when (fboundp 'magit-status)
      (let ((root (or (and (fboundp 'pro-project-root) (pro-project-root)) default-directory)))
        (magit-status root)))))

(defun pro-git-log-current ()
  "Показать лог текущего репозитория."
  (interactive)
  (when (require 'magit nil t)
    (when (fboundp 'magit-log-current)
      (magit-log-current))))

(defun pro-git-dispatch ()
  "Открыть магитовский диспетчер."
  (interactive)
  (when (or (pro--package-provided-p 'magit) (require 'magit nil t))
    (when (fboundp 'magit-dispatch)
      (magit-dispatch))))

(provide 'pro-git)
