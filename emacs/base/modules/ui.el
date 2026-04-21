;; Русский: комментарии и пояснения оформлены в стиле учебника
;;; ui.el --- визуальная среда -*- lexical-binding: t; -*-

;; Этот модуль собирает внешний вид так, чтобы он был тихим, читаемым и полезным.

(require 'subr-x)

(defcustom pro-ui-code-font-family "Aporetic Sans Mono"
  "Шрифт для кода."
  :type 'string
  :group 'pro-ui)

(defcustom pro-ui-text-font-family "Aporetic Sans"
  "Шрифт для текста интерфейса."
  :type 'string
  :group 'pro-ui)

(defcustom pro-ui-font-height 130
  "Высота шрифта в десятых долях пункта."
  :type 'integer
  :group 'pro-ui)

(defcustom pro-ui-enable-ligatures t
  "Включать ли лигатуры в коде."
  :type 'boolean
  :group 'pro-ui)

(defcustom pro-ui-enable-icons t
  "Включать ли иконки в UI-слое."
  :type 'boolean
  :group 'pro-ui)

(defun pro-ui--font-available-p (family)
  "Проверить, доступен ли шрифт FAMILY."
  (find-font (font-spec :family family)))

(defun pro-ui--first-available-font (families)
  "Вернуть первый доступный шрифт из списка FAMILIES."
  (catch 'found
    (dolist (family families)
      (when (pro-ui--font-available-p family)
        (throw 'found family)))
    nil))

(defun pro-ui-apply-fonts ()
  "Применить шрифты к графическому фрейму."
  (when (display-graphic-p)
    (let ((code-font (or (pro-ui--first-available-font '("Fira Code" "JetBrains Mono" "Aporetic Sans Mono" "DejaVu Sans Mono"))
                         pro-ui-code-font-family))
          (text-font (or (pro-ui--first-available-font '("Fira Sans" "Inter" "Aporetic Sans" "DejaVu Sans"))
                         pro-ui-text-font-family)))
      (set-face-attribute 'default nil :family code-font :height pro-ui-font-height)
      (set-face-attribute 'fixed-pitch nil :family code-font :height 1.0)
      (set-face-attribute 'variable-pitch nil :family text-font :height 1.0)
      (push `(font . ,(format "%s-%d" code-font (/ pro-ui-font-height 10))) default-frame-alist)
      (push `(font . ,(format "%s-%d" code-font (/ pro-ui-font-height 10))) initial-frame-alist))))

(defun pro-ui-apply-ligatures ()
  "Включить лигатуры, если они доступны."
  (when (and pro-ui-enable-ligatures (require 'ligature nil t))
    (ligature-set-ligatures 'prog-mode
                            '("www" "|||" "|>" ":=" ":-" ":>" "->" "->>" "-->" "<=" ">=" "==" "===" "!=" "&&" "||" "///" "/*" "*/" "::" "::=" "++" "**" "~~" "%%"))
    (global-ligature-mode t)))

(defun pro-ui--try-require (feature)
  "Безопасно подключить FEATURE."
  (or (and (boundp 'pro-packages-provided-by-nix)
           (memq feature pro-packages-provided-by-nix)
           (require feature nil t))
      (when (and (fboundp 'pro-packages--maybe-install)
                 (pro-packages--maybe-install feature t))
        (require feature nil t))))

(defun pro-ui-apply-icons ()
  "Подключить полезные иконки без обязательной зависимости."
  (when (and pro-ui-enable-icons (display-graphic-p))
    (when (pro-ui--try-require 'all-the-icons)
      (setq all-the-icons-scale-factor 1.0))
    (when (pro-ui--try-require 'kind-icon)
      (when (boundp 'corfu-margin-formatters)
        (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter)))
    (when (pro-ui--try-require 'nerd-icons-ibuffer)
      (add-hook 'ibuffer-mode-hook #'nerd-icons-ibuffer-mode))
    (when (pro-ui--try-require 'treemacs-icons-dired)
      (add-hook 'dired-mode-hook #'treemacs-icons-dired-enable-once))))

(defun pro-ui-apply-tabs ()
  "Подключить pro-tabs, если пакет доступен."
  (when (display-graphic-p)
    (when (pro-ui--try-require 'pro-tabs)
      (setq pro-tabs-enable-icons t)
      (when (fboundp 'pro-tabs-mode)
        (pro-tabs-mode 1)))))

(defun pro-ui-apply-completion ()
  "Подключить полезные подсказки для завершения."
  (when (display-graphic-p)
    (when (pro-ui--try-require 'corfu)
      (global-corfu-mode 1)
      (setq corfu-auto t
            corfu-cycle t))
    (when (and (pro-ui--try-require 'kind-icon)
               (boundp 'corfu-margin-formatters))
      (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))))

(provide 'ui)
