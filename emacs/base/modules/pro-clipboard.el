;;; pro-clipboard.el --- Clipboard history helper (C-x y suggestion) -*- lexical-binding: t; -*-
;;
;; Назначение: предоставить лёгкий адаптер для истории буфера обмена.
;; Контракт: Не назначает глобальных биндов. Предоставляет функцию
;; `pro/clipboard-yank-pop' которая выбирает реализацию из доступных
;; пакетов: prefer `consult-yank-from-kill-ring', then `browse-kill-ring', else `yank-pop'.
;; Все действия безопасны в headless режиме.

(defgroup pro-clipboard nil
  "Clipboard history helpers for pro-emacs." :group 'pro)

(defun pro/clipboard-yank-pop (&optional arg)
  "Yank from clipboard history.

If `consult' is available, call `consult-yank-from-kill-ring'. If
`browse-kill-ring' is available, call it. Otherwise fall back to
`yank-pop'. ARG is forwarded to `yank-pop' when used.
Function is safe to call in headless (non-GUI) sessions.
"
  (interactive "p")
  (cond
   ((and (require 'consult nil t) (fboundp 'consult-yank-from-kill-ring))
    (call-interactively #'consult-yank-from-kill-ring))
   ((and (require 'browse-kill-ring nil t) (fboundp 'browse-kill-ring))
    (call-interactively #'browse-kill-ring))
   (t
    ;; fallback: emulate basic yank-pop behaviour
    (if (fboundp 'yank-pop)
        (call-interactively #'yank-pop)
      (user-error "No suitable yank/pop function available")))))

;;; Register suggested key (do not bind globally here)
(with-eval-after-load 'pro-keys
  (condition-case _err
      (when (fboundp 'pro/register-module-keys)
        (pro/register-module-keys 'clipboard
                                  '(("C-x y" . pro/clipboard-yank-pop))))
    (error (message "pro/clipboard: failed to register suggestion"))))

(provide 'pro-clipboard)

;;; pro-clipboard.el ends here
