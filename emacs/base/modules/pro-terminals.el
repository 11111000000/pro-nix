;;; pro-terminals.el --- Интеграция терминалов (vterm, eshell, ansi-term, shell-pop) -*- lexical-binding: t; -*-
;;
;; Контракт:
;; - Публичные команды: pro/eshell-toggle, pro/vterm-dedicated-toggle,
;;   pro/vterm-dedicated-close, pro/shell-pop, pro/ansi-term-toggle,
;;   pro/multi-vterm-next, pro/multi-vterm-prev, pro/vterm-yank,
;;   pro/vterm-interrupt.
;; - Все команды безопасны: проверяют доступность модуля через `fboundp' /
;;   `locate-library'. Если пакет недоступен — сообщение в *Messages*
;;   без падения.
;; - Биндинги не навязываются глобально: рекомендации регистрируются
;;   через `pro/register-module-keys' и попадают в emacs-keys.org
;;   (глобально — C-c t *, локально — C-c v *).
;;
;; Last reviewed: 2026-07-13

(require 'subr-x)

(defgroup pro-terminals nil
  "Helpers for vterm, eshell, ansi-term, shell-pop." :group 'pro-ui)

(defcustom pro-terminals-enable t
  "Включить вспомогательные функции работы с терминалами."
  :type 'boolean :group 'pro-terminals)

(defcustom pro-terminals-shell-pop-height 43
  "Высота shell-pop окна в процентах от фрейма."
  :type 'integer :group 'pro-terminals)

;; ── Public commands ──────────────────────────────────────────────────────

(defun pro/eshell-toggle ()
  "Toggle eshell window. No-op если eshell-toggle недоступен."
  (interactive)
  (if (fboundp 'eshell-toggle)
      (eshell-toggle)
    (message "[pro-terminals] eshell-toggle недоступен — установите eshell-toggle")))

(defun pro/multi-vterm-project ()
  "Open multi-vterm in project root. No-op если multi-vterm-project недоступен."
  (interactive)
  (if (fboundp 'multi-vterm-project)
      (multi-vterm-project)
    (message "[pro-terminals] multi-vterm-project недоступен")))

(defun pro/vterm-dedicated-toggle ()
  "Toggle dedicated vterm в side window. No-op если multi-vterm-dedicated-toggle недоступен."
  (interactive)
  (cond
   ((fboundp 'multi-vterm-dedicated-toggle)
    (multi-vterm-dedicated-toggle))
   ((fboundp 'vterm-toggle)
    (vterm-toggle))
   (t (message "[pro-terminals] vterm-dedicated-toggle недоступен"))))

(defun pro/vterm-dedicated-close ()
  "Закрыть dedicated vterm буфер. Идемпотентно."
  (interactive)
  (let ((buf (get-buffer "*vterminal*")))
    (cond
     (buf (kill-buffer buf)
          (message "[pro-terminals] dedicated vterm закрыт"))
     ((fboundp 'multi-vterm-dedicated-close)
      (multi-vterm-dedicated-close))
     (t (message "[pro-terminals] dedicated vterm не открыт")))))

(defun pro/shell-pop ()
  "Pop-up system shell через shell-pop.el. No-op если недоступен."
  (interactive)
  (cond
   ((fboundp 'shell-pop)
    (let ((shell-pop-window-height pro-terminals-shell-pop-height))
      (shell-pop)))
   ((fboundp 'vterm)
    (vterm))
   (t (message "[pro-terminals] shell-pop и vterm недоступны"))))

(defun pro/ansi-term-toggle ()
  "Toggle ansi-term. Создаёт *ansi-term* buffer если нет, иначе switch-to-buffer."
  (interactive)
  (let ((buf (get-buffer "*ansi-term*")))
    (cond
     (buf
      (if (string= (buffer-name (current-buffer)) "*ansi-term*")
          (kill-buffer buf)
        (switch-to-buffer buf)))
      ((fboundp 'ansi-term)
       (ansi-term (executable-find "bash")))
     (t (message "[pro-terminals] ansi-term недоступен")))))

(defun pro/multi-vterm-next ()
  "Cycle to next multi-vterm buffer."
  (interactive)
  (cond
   ((fboundp 'multi-vterm-next)
    (multi-vterm-next))
   (t
    (let* ((current (current-buffer))
           (next (or (cadr (cl-remove-if-not
                            (lambda (b) (string-match-p "\\*vterminal" (buffer-name b)))
                            (buffer-list)
                            :from-end t))
                     (current-buffer))))
      (switch-to-buffer next)))))

(defun pro/multi-vterm-prev ()
  "Cycle to previous multi-vterm buffer."
  (interactive)
  (cond
   ((fboundp 'multi-vterm-prev)
    (multi-vterm-prev))
   (t
    (let* ((current (current-buffer))
           (prev (or (cadr (cl-remove-if-not
                            (lambda (b) (string-match-p "\\*vterminal" (buffer-name b)))
                            (buffer-list)))
                     (current-buffer))))
      (switch-to-buffer prev)))))

(defun pro/vterm-yank ()
  "Yank from kill-ring into vterm with proper handling."
  (interactive)
  (when (derived-mode-p 'vterm-mode)
    (let ((text (current-kill 0)))
      (when (fboundp 'vterm-send-string)
        (vterm-send-string text)))))

(defun pro/vterm-interrupt ()
  "Send SIGINT in vterm (C-c C-c equivalent)."
  (interactive)
  (when (and (derived-mode-p 'vterm-mode) (fboundp 'vterm-send-C-c))
    (vterm-send-C-c)))

;; ── vterm-mode local niceties (history, yank, C-\) ──────────────────────

(when (and pro-terminals-enable (require 'vterm nil t))
  (add-hook 'vterm-mode-hook
            (lambda ()
              (setq-local scroll-margin 0)
              (when (fboundp 'tab-line-mode) (tab-line-mode 1))
              ;; C-\\ (toggle-input-method) — перехватываем на уровне Emacs,
              ;; иначе vterm отправит ESC в терминал и input-method не сработает.
              (define-key vterm-mode-map (kbd "C-\\") #'toggle-input-method)
              ;; History navigation: M-p / M-n → underlying shell history
              (defun pro/vterm-history-previous ()
                "Send Up to vterm (previous history)."
                (interactive)
                (when (derived-mode-p 'vterm-mode)
                  (if (fboundp 'vterm-send-key)
                      (ignore-errors (vterm-send-key "<up>"))
                    (when (fboundp 'vterm-send-string)
                      (vterm-send-string "\e[A")))))
              (defun pro/vterm-history-next ()
                "Send Down to vterm (next history)."
                (interactive)
                (when (derived-mode-p 'vterm-mode)
                  (if (fboundp 'vterm-send-key)
                      (ignore-errors (vterm-send-key "<down>"))
                    (when (fboundp 'vterm-send-string)
                      (vterm-send-string "\e[B")))))
              (define-key vterm-mode-map (kbd "M-p") #'pro/vterm-history-previous)
              (define-key vterm-mode-map (kbd "M-n") #'pro/vterm-history-next)
              ;; Yank into vterm: C-y → insert last kill-ring entry
              (define-key vterm-mode-map (kbd "C-y") #'pro/vterm-yank))))

;; ── Register module suggestions for keys layer ───────────────────────────

(with-eval-after-load 'pro-keys
  (when (fboundp 'pro/register-module-keys)
    (pro/register-module-keys
     'terminals
     '(("C-c t e" . pro/eshell-toggle)
       ("C-c t v" . pro/multi-vterm-project)
       ("C-c t d" . pro/vterm-dedicated-toggle)
       ("C-c t D" . pro/vterm-dedicated-close)
       ("C-c t s" . pro/shell-pop)
       ("C-c t t" . pro/ansi-term-toggle)
       ("C-c t n" . pro/multi-vterm-next)
       ("C-c t p" . pro/multi-vterm-prev)
       ("C-c t c" . vterm-copy-mode)
       ("C-c t y" . pro/vterm-yank)
       ("C-c t i" . pro/vterm-interrupt)
       ("C-c t ?" . pro/terminal-transient)
       ("C-c v y" . pro/vterm-yank)
       ("C-c v i" . pro/vterm-interrupt)
       ("C-c v c" . vterm-copy-mode)))))

(provide 'pro-terminals)
;;; pro-terminals.el ends here
