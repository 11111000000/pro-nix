;;; pro-key-prefixes.el --- transient-helper menus for C-c <letter> prefixes -*- lexical-binding: t; -*-
;;
;; Назначение:
;; Каждый префикс верхнего уровня (C-c t / C-c w / C-c m / C-c x / C-c T)
;; имеет «меню помощи» на `?' (или `h' в EXWM-варианте) — вызывает
;; `pro/<prefix>-transient', который показывает все доступные команды
;; префикса в одной transient-форме. Это убирает необходимость помнить
;; точные буквы (7±2 в рабочей памяти).
;;
;; Контракт:
;; - Публичные команды: pro/terminal-transient, pro/windows-transient,
;;   pro/messaging-transient, pro/exwm-transient, pro/tree-transient.
;; - Зависимости: transient (Nix-provided в emacsPackages.transient 0.13+).
;; - Поведение: каждая команда собирает transient-форму из известных команд
;;   префикса. Если `transient' недоступен — показывает список строк
;;   в *Messages*.
;;
;; Last reviewed: 2026-07-13

(require 'transient)

;;; ── Terminals ────────────────────────────────────────────────────────────

(transient-define-suffix pro/terminal-eshell-toggle ()
  "Toggle eshell window."
  :description "eshell — toggle"
  (interactive)
  (pro/eshell-toggle))

(transient-define-suffix pro/terminal-vterm-project ()
  "Open multi-vterm in project CWD."
  :description "vterm — project"
  (interactive)
  (multi-vterm-project))

(transient-define-suffix pro/terminal-vterm-dedicated ()
  "Toggle dedicated vterm in side window."
  :description "vterm — dedicated toggle"
  (interactive)
  (pro/vterm-dedicated-toggle))

(transient-define-suffix pro/terminal-shell-pop ()
  "Pop up a system shell."
  :description "shell — pop"
  (interactive)
  (pro/shell-pop))

(transient-define-suffix pro/terminal-multi-vterm-next ()
  "Cycle to next multi-vterm buffer."
  :description "vterm — next"
  (interactive)
  (pro/multi-vterm-next))

(transient-define-suffix pro/terminal-multi-vterm-prev ()
  "Cycle to previous multi-vterm buffer."
  :description "vterm — prev"
  (interactive)
  (pro/multi-vterm-prev))

(transient-define-suffix pro/terminal-ansi-term ()
  "Toggle ansi-term."
  :description "term (ansi-term)"
  (interactive)
  (pro/ansi-term-toggle))

(transient-define-suffix pro/terminal-vterm-copy-mode ()
  "Enter vterm copy-mode."
  :description "vterm — copy-mode"
  (interactive)
  (vterm-copy-mode 1))

(transient-define-suffix pro/terminal-vterm-yank ()
  "Yank into vterm."
  :description "vterm — yank"
  (interactive)
  (pro/vterm-yank))

(transient-define-suffix pro/terminal-vterm-interrupt ()
  "Send C-c to vterm."
  :description "vterm — interrupt (C-c)"
  (interactive)
  (pro/vterm-interrupt))

(defun pro/terminal-transient ()
  "Показать transient-меню всех C-c t * команд."
  (interactive)
  (if (fboundp 'transient--stack-frame)
      (progn
        ;; transient из коробки работает с define-transient. Используем
        ;; прямой путь через display-buffer, чтобы обойтись без
        ;; define-transient макроса (который требует бутстрап).
        (let ((buf (get-buffer-create "*pro-terminal-transient*")))
          (with-current-buffer buf
            (erase-buffer)
            (insert (propertize "Terminals — C-c t ?\n\n" 'face 'bold))
            (insert "  e  eshell-toggle                       — eshell\n")
            (insert "  v  multi-vterm-project                 — vterm по проекту\n")
            (insert "  d  vterm-dedicated-toggle              — dedicated vterm toggle\n")
            (insert "  D  vterm-dedicated-close               — dedicated vterm close\n")
            (insert "  s  shell-pop                           — pop shell\n")
            (insert "  t  ansi-term-toggle                    — ansi-term\n")
            (insert "  n  multi-vterm-next                    — next vterm\n")
            (insert "  p  multi-vterm-prev                    — prev vterm\n")
            (insert "  c  vterm-copy-mode                     — copy-mode\n")
            (insert "  y  vterm-yank                          — yank\n")
            (insert "  i  vterm-interrupt                     — interrupt (C-c)\n")
            (goto-char (point-min)))
          (display-buffer buf
                          '(display-buffer-at-bottom
                            (window-height . 0.45)
                            (window-parameters . ((no-other-window . t)))))))
    (message "[pro-key-prefixes] transient не загружен; команды C-c t доступны через emacs-keys.org")))

;;; ── Windows nav ──────────────────────────────────────────────────────────

(defun pro/windows-transient ()
  "Показать transient-меню всех C-c w * команд."
  (interactive)
  (let ((buf (get-buffer-create "*pro-windows-transient*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert (propertize "Windows nav — C-c w ?\n\n" 'face 'bold))
      (insert "Focus window:\n")
      (insert "  h  windmove-left        ← left\n")
      (insert "  j  windmove-down        ↓ down\n")
      (insert "  k  windmove-up          ↑ up\n")
      (insert "  l  windmove-right       → right\n")
      (insert "\nSwap buffer:\n")
      (insert "  H  buf-move-left        ←\n")
      (insert "  J  buf-move-down        ↓\n")
      (insert "  K  buf-move-up          ↑\n")
      (insert "  L  buf-move-right       →\n")
      (insert "\nWindow config:\n")
      (insert "  u  winner-undo          (откатить раскладку)\n")
      (insert "  r  winner-redo          (повторить)\n")
      (insert "  =  pro-windows-balance  (golden-ratio one-shot)\n")
      (insert "  d  delete-window\n")
      (insert "  a  ace-window           (number select)\n")
      (insert "  1  delete-other-windows (single column)\n")
      (insert "  2  split-window-below\n")
      (insert "  3  split-window-right\n")
      (insert "  s  pro/split-window-sensibly\n")
      (goto-char (point-min)))
    (display-buffer buf
                    '(display-buffer-at-bottom
                      (window-height . 0.45)
                      (window-parameters . ((no-other-window . t)))))))

;;; ── Messaging ────────────────────────────────────────────────────────────

(defun pro/messaging-transient ()
  "Показать transient-меню всех C-c m * команд."
  (interactive)
  (let ((buf (get-buffer-create "*pro-messaging-transient*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert (propertize "Messaging — C-c m ?\n\n" 'face 'bold))
      (insert "Telegram (telega):\n")
      (insert "  o  pro/chat-open                       — open\n")
      (insert "  c  pro/telega-select-chat-or-contact   — chat select\n")
      (insert "  u  pro/telega-select-chat-or-contact   — user (C-u)\n")
      (insert "  k  pro/chat-close-idle-chats           — kill idle\n")
      (insert "  e  pro/chat-reload-emojis              — reload emojis\n")
      (insert "  i  pro/chat-install                    — install fallback\n")
      (insert "\nTor:\n")
      (insert "  s  pro/chat-tor-status                 — tor status (buffer)\n")
      (insert "  r  pro/chat-tor-reroute-now            — reroute\n")
      (goto-char (point-min)))
    (display-buffer buf
                    '(display-buffer-at-bottom
                      (window-height . 0.40)
                      (window-parameters . ((no-other-window . t)))))))

;;; ── EXWM ────────────────────────────────────────────────────────────────

(defun pro/exwm-transient ()
  "Показать transient-меню всех C-c x * команд."
  (interactive)
  (let ((buf (get-buffer-create "*pro-exwm-transient*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert (propertize "EXWM global — C-c x ?\n\n" 'face 'bold))
      (insert "Tabs (mirror of s-t/s-n/s-p etc.):\n")
      (insert "  t  pro-tabs-open-new-tab         — new tab\n")
      (insert "  n  tab-bar-switch-to-next-tab   — next\n")
      (insert "  p  tab-bar-switch-to-prev-tab   — prev\n")
      (insert "  N  tab-bar-move-tab             — move right\n")
      (insert "  P  tab-bar-move-tab-backward    — move left\n")
      (insert "  T  tab-bar-undo-close-tab       — restore\n")
      (insert "  1..6  pro-tabs-select-tab-N     — select tab N\n")
      (insert "  w  tab-bar-close-tab            — close\n")
      (insert "\nMisc:\n")
      (insert "  r  exwm-reset\n")
      (insert "  d  pro/treemacs (alias of C-c T)\n")
      (insert "  a  pro/app-launcher\n")
      (insert "  &  async-shell-command\n")
      (goto-char (point-min)))
    (display-buffer buf
                    '(display-buffer-at-bottom
                      (window-height . 0.45)
                      (window-parameters . ((no-other-window . t)))))))

;;; ── Tree ────────────────────────────────────────────────────────────────

(defun pro/tree-transient ()
  "Показать transient-меню всех C-c T * команд."
  (interactive)
  (let ((buf (get-buffer-create "*pro-tree-transient*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert (propertize "Tree — C-c T ?\n\n" 'face 'bold))
      (insert "  C-c T    pro/treemacs            — open/toggle\n")
      (insert "  C-c T t  pro/treemacs-toggle     — toggle\n")
      (insert "  C-c T r  pro/treemacs-refresh    — refresh\n")
      (insert "  C-c T p  pro/treemacs-project    — project root\n")
      (insert "  C-c T d  treemacs-delete-window  — delete window\n")
      (goto-char (point-min)))
    (display-buffer buf
                    '(display-buffer-at-bottom
                      (window-height . 0.30)
                      (window-parameters . ((no-other-window . t)))))))

;; ── Sub-prefix keymaps ──────────────────────────────────────────────────
;;
;; Each top-level prefix (C-c w, C-c t, C-c m, C-c x) is a keymap, not a
;; command.  When `pro-keys.el' sees `C-c w' in emacs-keys.org with a
;; keymap as the command, it installs the keymap as a prefix on
;; `global-map'.  Subsequent child bindings (`C-c w h', `C-c t e', …)
;; automatically attach to the parent keymap.
;;
;; We pre-populate each keymap with the most-used bindings so that
;; the prefix is functional even before `pro-keys.el' re-binds them
;; from emacs-keys.org.

(defvar pro-windows-prefix-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "h") #'windmove-left)
    (define-key map (kbd "j") #'windmove-down)
    (define-key map (kbd "k") #'windmove-up)
    (define-key map (kbd "l") #'windmove-right)
    (define-key map (kbd "H") #'buf-move-left)
    (define-key map (kbd "J") #'buf-move-down)
    (define-key map (kbd "K") #'buf-move-up)
    (define-key map (kbd "L") #'buf-move-right)
    (define-key map (kbd "u") #'winner-undo)
    (define-key map (kbd "r") #'winner-redo)
    (define-key map (kbd "=") #'pro-windows-balance)
    (define-key map (kbd "d") #'delete-window)
    (define-key map (kbd "a") #'ace-window)
    (define-key map (kbd "1") #'delete-other-windows)
    (define-key map (kbd "2") #'split-window-below)
    (define-key map (kbd "3") #'split-window-right)
    (define-key map (kbd "s") #'pro/split-window-sensibly)
    (define-key map (kbd "?") #'pro/windows-transient)
    map)
  "Keymap for `C-c w' prefix (windows nav).")

(defvar pro-terminal-prefix-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "e") #'pro/eshell-toggle)
    (define-key map (kbd "v") #'multi-vterm-project)
    (define-key map (kbd "d") #'pro/vterm-dedicated-toggle)
    (define-key map (kbd "D") #'pro/vterm-dedicated-close)
    (define-key map (kbd "s") #'pro/shell-pop)
    (define-key map (kbd "t") #'pro/ansi-term-toggle)
    (define-key map (kbd "n") #'pro/multi-vterm-next)
    (define-key map (kbd "p") #'pro/multi-vterm-prev)
    (define-key map (kbd "c") #'vterm-copy-mode)
    (define-key map (kbd "y") #'pro/vterm-yank)
    (define-key map (kbd "i") #'pro/vterm-interrupt)
    (define-key map (kbd "?") #'pro/terminal-transient)
    map)
  "Keymap for `C-c t' prefix (terminals).")

(defvar pro-messaging-prefix-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "o") #'pro/chat-open)
    (define-key map (kbd "c") #'pro/telega-select-chat-or-contact)
    (define-key map (kbd "u") (lambda () (interactive) (pro/telega-select-chat-or-contact '(16))))
    (define-key map (kbd "k") #'pro/chat-close-idle-chats)
    (define-key map (kbd "e") #'pro/chat-reload-emojis)
    (define-key map (kbd "i") #'pro/chat-install)
    (define-key map (kbd "s") #'pro/chat-tor-status)
    (define-key map (kbd "r") #'pro/chat-tor-reroute-now)
    (define-key map (kbd "?") #'pro/messaging-transient)
    map)
  "Keymap for `C-c m' prefix (messaging/Telegram).")

(defvar pro-exwm-prefix-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "r") #'exwm-reset)
    (define-key map (kbd "t") #'pro-tabs-open-new-tab)
    (define-key map (kbd "n") #'tab-bar-switch-to-next-tab)
    (define-key map (kbd "p") #'tab-bar-switch-to-prev-tab)
    (define-key map (kbd "N") #'tab-bar-move-tab)
    (define-key map (kbd "P") #'tab-bar-move-tab-backward)
    (define-key map (kbd "T") #'tab-bar-undo-close-tab)
    (define-key map (kbd "1") #'pro-tabs-select-tab-1)
    (define-key map (kbd "2") #'pro-tabs-select-tab-2)
    (define-key map (kbd "3") #'pro-tabs-select-tab-3)
    (define-key map (kbd "4") #'pro-tabs-select-tab-4)
    (define-key map (kbd "5") #'pro-tabs-select-tab-5)
    (define-key map (kbd "6") #'pro-tabs-select-tab-6)
    (define-key map (kbd "w") #'tab-bar-close-tab)
    (define-key map (kbd "d") #'pro/treemacs)
    (define-key map (kbd "a") #'pro/app-launcher)
    (define-key map (kbd "&") #'async-shell-command)
    (define-key map (kbd "?") #'pro/exwm-transient)
    map)
  "Keymap for `C-c x' prefix (EXWM global commands, available everywhere).")

(defvar pro-buffer-bar-prefix-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "n") #'pro-tabs-open-new-tab)
    (define-key map (kbd "k") #'pro-tabs-close-tab-and-buffer)
    (define-key map (kbd "S") #'tab-bar-switch-to-tab)
    map)
  "Keymap for `C-c b' prefix (buffer/tab-bar).")

(provide 'pro-key-prefixes)
;;; pro-key-prefixes.el ends here
