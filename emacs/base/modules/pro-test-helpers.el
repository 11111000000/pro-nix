;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; test-helpers.el --- headless test helpers -*- lexical-binding: t; -*-

(require 'subr-x)

(defvar pro-test--load-errors nil)

(defun pro-test--safe-load (file)
  "Load FILE and collect any error."
  (condition-case err
      (progn
        (load file nil t)
        t)
    (error
     (push (format "%s: %s" file (error-message-string err)) pro-test--load-errors)
     nil)))

(defun pro-test-load-base (modules-dir)
  "Load base Emacs modules from MODULES-DIR and return errors."
  (setq pro-test--load-errors nil)
  (dolist (file '("core.el" "ui.el" "keys.el" "nav.el" "ai.el" "agent.el" "chat.el"))
    (pro-test--safe-load (expand-file-name file modules-dir)))
  (nreverse pro-test--load-errors))

(defun pro-test-headless-summary ()
  "Return a compact summary string for headless runs."
  (format "loaded=%s errors=%s"
          (if pro-test--load-errors "no" "yes")
          (length pro-test--load-errors)))

(provide 'pro-test-helpers)
