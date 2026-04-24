;;; pro-terminals.el --- Интеграция терминалов (vterm, eshell) -*- lexical-binding: t; -*-
;;
;; Этот модуль предоставляет небольшие, безопасные вспомогательные функции
;; для работы с терминалами внутри Emacs. Он не навязывает глобальных
;; сочетаний клавиш — рекомендации по биндингам регистрируются через API
;; `pro/register-module-keys' и могут быть экспортированы в виде Org-таблиц.
;;
;; Стиль документации: подробные комментарии и докстринги на русском языке
;; чтобы код служил одновременно реализацией и учебным материалом.

(require 'subr-x)

(defcustom pro-terminals-enable t
  "Включить вспомогательные функции работы с терминалами (vterm/eshell).

Если установить в nil, модуль не будет подключать нигде дополнительных
хэлперов. Этот флаг не управляет установкой пакетов: убедитесь, что
vterm доступен в вашей системе (Nix/Home-Manager или ELPA).
"
  :type 'boolean :group 'pro-ui)

;; Основной код модуля выполняется только когда включён флаг и пакет
;; vterm доступен. Все функции тщательно ограничены по контексту
;; (проверяют режимы) чтобы избежать побочных эффектов в других буферах.
(when (and pro-terminals-enable (require 'vterm nil t))
  ;; Example helper: yank into vterm with proper escaping
  (defun pro/vterm-yank ()
    "Yank from kill-ring into vterm with proper handling."
    (interactive)
    (when (derived-mode-p 'vterm-mode)
      (let ((text (current-kill 0)))
        (vterm-send-string text))))

  (defun pro/vterm-interrupt ()
    "Send SIGINT in vterm (C-c C-c equivalent)."
    (interactive)
    (when (derived-mode-p 'vterm-mode)
      (vterm-send-C-c)))

  ;; Setup minor vterm niceties
  (add-hook 'vterm-mode-hook
            (lambda ()
              (setq-local scroll-margin 0)
              ;; enable tab-line in vterm for quick buffer switching
              (when (fboundp 'tab-line-mode) (tab-line-mode 1))
              ;; prefer sane history and copy mode
               (when (fboundp 'vterm-copy-mode)
                  (vterm-copy-mode 0))
               ;; Additional small helpers ported from ~/pro if available
               (when (fboundp 'vterm-copy-mode)
                 ;; Escape from copy mode back to prompt
                 (define-key vterm-copy-mode-map (kbd "C-g")
                   (lambda () (interactive) (when (bound-and-true-p vterm-copy-mode) (vterm-copy-mode -1) (when (and (boundp 'vterm--process-marker) vterm--process-marker) (goto-char vterm--process-marker))))))
               ;; Move up in line-mode or enter copy-mode then move
               (define-key vterm-mode-map (kbd "C-p")
                 (lambda () (interactive)
                   (unless (bound-and-true-p vterm-copy-mode)
                     (vterm-copy-mode 1))
                   (when (bound-and-true-p vterm-copy-mode)
                     (let ((cmd (or (lookup-key vterm-copy-mode-map (kbd "<up>") )
                                    (lookup-key vterm-copy-mode-map (kbd "p")))))
                       (when cmd (call-interactively cmd))))))
               ;; Optional consult integration: provide a yank-pop that works in vterm
               (when (and (fboundp 'consult-yank-pop) (fboundp 'vterm-send-string))
                 (defun pro/vterm-consult-yank-pop ()
                   "Yank from consult history into vterm. Returns the chosen string for testing."
                   (interactive)
                   (when (derived-mode-p 'vterm-mode)
                     (let ((s (consult-yank-pop)))
                       (when s (vterm-send-string s))
                       s))))
               ;; Install local keymap for vterm helpers if keys module present
               (when (and (boundp 'pro/registered-module-keys)
                          (fboundp 'pro/register-module-keys))
                 ;; register suggested keys for vterm helpers (non-binding)
                  (with-eval-after-load 'pro-keys
                    (when (fboundp 'pro/register-module-keys)
                       (pro/register-module-keys 'terminals
                                                '( ("C-c v y" . pro/vterm-yank)
                                                   ("C-c v i" . pro/vterm-interrupt)
                                                   ("C-c v c" . vterm-copy-mode)))))))))

(provide 'pro-terminals)

;;; pro-terminals.el ends here
