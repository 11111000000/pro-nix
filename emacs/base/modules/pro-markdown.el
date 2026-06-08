;;; pro-markdown.el --- Markdown-режим и локальные привычки -*- lexical-binding: t; -*-

;; Назначение: подключить markdown-mode для *.md / *.markdown / *.mdown и задать
;; минимальный набор локальных привычек, согласованных со стилем pro-org.el.

(when (or (pro--package-provided-p 'markdown-mode)
          (pro-packages--maybe-install 'markdown-mode t)
          (require 'markdown-mode nil t))
  ;; Рендерить блоки кода по языку и масштабировать заголовки в самом буфере.
  ;; `markdown-open-command' — внешний просмотрщик (xdg-open подхватывает
  ;; дефолтный браузер, `browse-url' обрабатывает вызовы из Emacs).
  (setq markdown-fontify-code-blocks-natively t
        markdown-header-scaling t
        markdown-open-command "xdg-open")

  (defun pro-markdown-setup ()
    "Локальные настройки для буфера markdown-mode."
    (setq-local truncate-lines nil)
    (setq-local word-wrap t))
  (add-hook 'markdown-mode-hook #'pro-markdown-setup))

(provide 'pro-markdown)

;;; pro-markdown.el ends here
