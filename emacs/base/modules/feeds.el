;;; feeds.el --- ленты новостей -*- lexical-binding: t; -*-

;; Этот модуль удерживает ленты как отдельную рабочую поверхность, без лишнего шума.

(defun pro-feeds-open ()
  "Открыть ленты, если пакет доступен."
  (interactive)
  (when (or (pro--package-provided-p 'elfeed) (pro-packages--maybe-install 'elfeed t) (require 'elfeed nil t))
    ;; elfeed may not define the top-level `elfeed' command until loaded.
    (when (fboundp 'elfeed)
      (elfeed))))

(provide 'feeds)
