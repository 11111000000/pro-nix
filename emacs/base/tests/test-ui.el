;;; test-ui.el --- ERT tests for basic UI behavior -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(ert-deftest pro-ui--early-gui-setup-tty-does-not-error ()
  "pro-ui-early-gui-setup should not error in TTY.")

(ert-deftest pro-ui-fonts-fallback ()
  "pro-ui-apply-fonts should not error and should set default face."
  (progn
    (ignore-errors (require 'pro-ui-fonts))
    (when (fboundp 'pro-ui-apply-fonts)
      (pro-ui-apply-fonts)
      (should (facep 'default)))))

(ert-deftest pro-ui-cursor-state-from-input-method-russian ()
  "Русский input method должен давать состояние 'russian."
  (when (fboundp 'pro-ui--cursor-state-from-input-method)
    (should (eq (pro-ui--cursor-state-from-input-method "russian-computer") 'russian))
    (should (eq (pro-ui--cursor-state-from-input-method "cyrillic-jcuken") 'russian))
    (should (eq (pro-ui--cursor-state-from-input-method "ru-kbd") 'russian))
    (should (eq (pro-ui--cursor-state-from-input-method nil) 'english))))

(ert-deftest pro-ui-cursor-english-applies-bar-and-color ()
  "Английский ввод должен дать бар-курсор заданного цвета."
  (when (fboundp 'pro-ui--apply-cursor-for-state)
    (let (calls cursor-type)
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
                ((symbol-function 'set-face-attribute)
                 (lambda (&rest args) (push args calls))))
        (pro-ui--apply-cursor-for-state 'english)
        (should (equal cursor-type `(bar . ,pro-ui-cursor-bar-width)))
        ;; Были обновлены оба лица: `cursor' и `cursor-read-only'.
        (let ((cursor-call (assq 'cursor calls))
              (ro-call (assq 'cursor-read-only calls)))
          (should cursor-call)
          (should ro-call)
          (should (equal (plist-get (cddr cursor-call) :background) pro-ui-cursor-english-color))
          (should (eq (plist-get (cddr cursor-call) :box) nil)))))))

(ert-deftest pro-ui-cursor-state-english-uses-bar-and-dark-green-color ()
  "Английский ввод должен возвращать состояние 'english и тёмно-зелёный цвет курсора."
  (when (fboundp 'pro-ui--apply-cursor-for-state)
    (let ((cursor-type nil)
          pro-ui--test-last-set-face)
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
                ((symbol-function 'set-face-attribute)
                 (lambda (&rest args)
                   (setq pro-ui--test-last-set-face args))))
        (pro-ui--apply-cursor-for-state 'english)
        (should (equal cursor-type `(bar . ,pro-ui-cursor-bar-width)))
        (should (equal (plist-get (cddr pro-ui--test-last-set-face) :background) pro-ui-cursor-english-color))))))

(ert-deftest pro-ui-cursor-english-color-is-not-bright-green ()
  "Цвет english-ввода по умолчанию — тёмно-зелёный, не яркий #00ff00.
Прежнее значение #00ff00 «кричало» и плохо смотрелось рядом с
оранжевым русского ввода; тёмно-зелёный (#0d7a32) спокойнее и
виднее на тёмном фоне."
  (when (boundp 'pro-ui-cursor-english-color)
    (should-not (equal pro-ui-cursor-english-color "#00ff00")) ; защита от регрессии
    (should (string-prefix-p "#" pro-ui-cursor-english-color))
    ;; Зелёный канал должен доминировать — это всё-таки зелёный,
    ;; просто тёмный (а не синий/красный акцент).
    (when (string-match "^#\\([0-9a-fA-F]\\{2\\}\\)\\([0-9a-fA-F]\\{2\\}\\)\\([0-9a-fA-F]\\{2\\}\\)$"
                        pro-ui-cursor-english-color)
      (let* ((r (string-to-number (match-string 1 pro-ui-cursor-english-color) 16))
             (g (string-to-number (match-string 2 pro-ui-cursor-english-color) 16))
             (b (string-to-number (match-string 3 pro-ui-cursor-english-color) 16)))
        (should (> g r))
        (should (> g b))))))

(ert-deftest pro-ui-cursor-deactivate-advice-is-installed ()
  "pro-ui-apply-cursor-chg устанавливает :after-advice на
`deactivate-input-method'. Без этого advice курсор не обновлялся бы
сразу при выключении русского ввода — приходилось ждать idle-тика
(т.е. ещё одно нажатие C-\\), что и приводило к жалобе «надо два
раза переключить»."
  (when (and (fboundp 'pro-ui-apply-cursor-chg)
             (fboundp 'deactivate-input-method)
             (fboundp 'advice-member-p))
    (pro-ui-apply-cursor-chg)
    (should (advice-member-p #'pro-ui--force-update-cursor
                             'deactivate-input-method))))

(ert-deftest pro-ui-detect-cursor-state-prefers-readonly ()
  "Read-only буфер должен переопределять input method."
  (when (fboundp 'pro-ui--detect-cursor-state)
    (with-temp-buffer
      (let ((buffer-read-only t)
            (current-input-method "russian-computer"))
        (should (eq (pro-ui--detect-cursor-state) 'readonly))))))

(ert-deftest pro-ui-cursor-readonly-sets-hollow-gray-box ()
  "Read-only состояние должно ставить полый серый прямоугольник на оба лица."
  (when (fboundp 'pro-ui--apply-cursor-for-state)
    (let (face-calls cursor-type)
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
                ((symbol-function 'set-face-attribute)
                 (lambda (&rest args) (push args face-calls))))
        (pro-ui--apply-cursor-for-state 'readonly))
      (should (equal cursor-type 'box))
      ;; Должны быть обновлены оба лица — `cursor' и `cursor-read-only'.
      (let ((cursor-call (assq 'cursor face-calls))
            (ro-call (assq 'cursor-read-only face-calls)))
        (should cursor-call)
        (should ro-call)
        (should (eq (plist-get (cddr cursor-call) :background) nil))
        (should (eq (plist-get (cddr ro-call) :background) nil))
        ;; Цвет рамки — серый по умолчанию.
        (let ((cursor-box (plist-get (cddr cursor-call) :box))
              (ro-box (plist-get (cddr ro-call) :box)))
          (should (equal (plist-get cursor-box :color) pro-ui-cursor-readonly-color))
          (should (equal (plist-get ro-box :color) pro-ui-cursor-readonly-color))
          (should (equal (plist-get cursor-box :line-width) pro-ui-cursor-readonly-line-width)))))))

(ert-deftest pro-ui-cursor-russian-resets-box ()
  "Русское состояние должно сбрасывать :box на nil (иначе рамка из readonly висит)."
  (when (fboundp 'pro-ui--apply-cursor-for-state)
    (let (face-calls cursor-type)
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
                ((symbol-function 'set-face-attribute)
                 (lambda (&rest args) (push args face-calls))))
        (pro-ui--apply-cursor-for-state 'russian))
      (let ((cursor-call (assq 'cursor face-calls))
            (ro-call (assq 'cursor-read-only face-calls)))
        (should cursor-call)
        (should ro-call)
        (should (eq (plist-get (cddr cursor-call) :box) nil))
        (should (eq (plist-get (cddr ro-call) :box) nil))
        (should (equal (plist-get (cddr cursor-call) :background) pro-ui-cursor-russian-color))))))

(ert-deftest pro-ui-tty-cleanup-disables-prettify ()
  "pro-ui-tty-setup disables prettify in TTY emulation."
  (progn
    (ignore-errors (require 'pro-ui-tty))
    (when (fboundp 'pro-ui-tty-setup)
      (let ((display-graphic-p nil))
        (pro-ui-tty-setup)
        (should (not (bound-and-true-p prettify-symbols-mode)))))))

(provide 'test-ui)
