;;; pro-ui-fonts.el --- Настройки шрифтов и типографии -*- lexical-binding: t; -*-
;;
;; Назначение: Конфигурация шрифтов, emoji и опций типографики для pro UI.
;; Контракт: Функции из этого модуля безопасно вызывать в headless среде — GUI‑
;; действия выполняются только при (display-graphic-p). Публичный API:
;;   - pro-ui-enable-mixed-pitch  (опция)
;;   - pro-ui-apply-fonts          (функция применения)
;; Proof: ./scripts/emacs-pro-wrapper.sh --batch -l scripts/emacs-e2e-assertions.el -l scripts/emacs-e2e-run-tests.el
;; Last reviewed: 2026-05-03
;;

(defgroup pro-ui-fonts nil
  "Настройки шрифтов и типографии для pro UI")

(defcustom pro-ui-enable-mixed-pitch nil
  "Включать mixed-pitch-mode для org-mode и help-mode по умолчанию.
Опция выключена по умолчанию потому, что некоторые пользователи предпочитают
моноширинные шрифты во всех буферах." 
  :type 'boolean
  :group 'pro-ui-fonts)

(defun pro-ui-apply-fonts ()
  "Применяет настройки шрифтов и набор для emoji. Безопасна для
повторного вызова; GUI-действия выполняются только при графическом дисплее."
  (when (display-graphic-p)
    (let* ((code-font (or (pro-ui--first-available-font
                           '("Fira Code" "JetBrains Mono" "Aporetic Sans Mono" "DejaVu Sans Mono"))
                          pro-ui-code-font-family))
           (text-font (or (pro-ui--first-available-font
                           '("Fira Sans" "Inter" "Aporetic Sans" "DejaVu Sans"))
                          pro-ui-text-font-family)))
      (set-face-attribute 'default nil :family code-font :height pro-ui-font-height)
      (set-face-attribute 'fixed-pitch nil :family code-font :height 1.0)
      (set-face-attribute 'variable-pitch nil :family text-font :height 1.0)
      (let ((font-spec `(font . ,(format "%s-%d" code-font (/ pro-ui-font-height 10)))))
        (unless (assq 'font default-frame-alist)
          (push font-spec default-frame-alist))
        (unless (assq 'font initial-frame-alist)
          (push font-spec initial-frame-alist)))
      ;; Emoji support
      (when (and (display-graphic-p) (fboundp 'set-fontset-font))
        (set-fontset-font "fontset-default" 'unicode "Noto Emoji" nil 'prepend)
        ;; Подключаем иконочный шрифт ТОЛЬКО для Private Use Area — иначе
        ;; prepend'ом перебьём CJK/Latin fallback на основной шрифт.
        ;; Nerd Fonts v2 живёт в BMP PUA (U+E000..U+EFFF);
        ;; Nerd Fonts v3 дополнительно в Supplementary PUA-B (U+100000..U+10FFFD).
        (let ((icon-candidates '("FiraCode Nerd Font" "Fira Code Nerd Font" "Hack Nerd Font"
                                  "DejaVu Sans Mono Nerd Font" "Nerd Font" "Symbols Nerd Font")))
          (if-let ((icon-font (pro-ui--first-available-font icon-candidates)))
              (progn
                (set-fontset-font "fontset-default" '(#xe000 . #xefff) icon-font nil 'append)
                (set-fontset-font "fontset-default" '(#x100000 . #x10fffd) icon-font nil 'append))
            (when pro-ui-enable-icons
              (message "pro-ui-fonts: ни один Nerd Font не найден (%s); иконки nerd-icons/all-the-icons не отрендерятся. Проверьте `fonts.packages' в modules/session-fonts.nix и `fc-list | grep -i nerd'."
                       (mapconcat #'identity icon-candidates ", "))))))
      ;; Mixed-pitch opt-in
      (when pro-ui-enable-mixed-pitch
        (when (pro-ui--try-require 'mixed-pitch)
          (add-hook 'org-mode-hook #'mixed-pitch-mode)
          (add-hook 'help-mode-hook #'mixed-pitch-mode)))
      ;; Prettify symbols in GUI
      (global-prettify-symbols-mode +1)
      (setq prettify-symbols-unprettify-at-point t))))

(provide 'pro-ui-fonts)
