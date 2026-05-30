;;; test-exwm-start.el --- Тесты запуска EXWM -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(load-file (expand-file-name "../modules/pro-exwm.el"
                             (file-name-directory (or load-file-name buffer-file-name))))

(ert-deftest pro/exwm-session-detection ()
  "XDG_CURRENT_DESKTOP проверки."
  (setenv "XDG_CURRENT_DESKTOP" "EXWM")
  (should (pro-exwm--session-p))
  (setenv "XDG_CURRENT_DESKTOP" "exwm")
  (should (pro-exwm--session-p))
  (setenv "XDG_CURRENT_DESKTOP" "none+exwm")
  (should (pro-exwm--session-p))
  (setenv "XDG_CURRENT_DESKTOP" "EXWM:GNOME")
  (should (pro-exwm--session-p))
  (setenv "XDG_CURRENT_DESKTOP" "GNOME")
  (should-not (pro-exwm--session-p))
  (setenv "XDG_CURRENT_DESKTOP" "")
  (should-not (pro-exwm--session-p))
  (setenv "XDG_CURRENT_DESKTOP" nil))

(defmacro pro-exwm-test--with-exwm-mocks (&rest body)
  "Run BODY with EXWM functions mocked so tests run without real EXWM."
  `(cl-letf (((symbol-function 'exwm-wm-mode)
              (lambda (&optional arg) (setq pro-exwm-test--wm-called arg)))
             ((symbol-function 'exwm-systemtray-mode)
              (lambda (&optional arg) (setq pro-exwm-test--tray-called arg)))
             ((symbol-function 'exwm-xim-mode)
              (lambda (&optional arg) (setq pro-exwm-test--xim-called arg)))
             ((symbol-function 'require)
              (lambda (_feat &optional _file _noerr) t))
             ((symbol-function 'fboundp)
              (lambda (sym) (memq sym '(exwm-systemtray-mode exwm-xim-mode))))
             ((symbol-function 'featurep)
              (lambda (feat &optional _sub) (eq feat 'exwm))))
     ,@body))

(defvar pro-exwm-test--wm-called nil)
(defvar pro-exwm-test--tray-called nil)
(defvar pro-exwm-test--xim-called nil)

(ert-deftest pro/exwm-starts-full-stack ()
  "В EXWM-сессии должны стартовать wm-mode, systemtray и xim."
  (let (pro-exwm-test--wm-called
        pro-exwm-test--tray-called
        pro-exwm-test--xim-called)
    (pro-exwm-test--with-exwm-mocks
      (setenv "XDG_CURRENT_DESKTOP" "EXWM")
      (unwind-protect
          (progn
            (pro-exwm-start-session)
            (should (equal pro-exwm-test--wm-called 1))
            (should (equal pro-exwm-test--tray-called 1))
            (should (equal pro-exwm-test--xim-called 1)))
        (setenv "XDG_CURRENT_DESKTOP" nil)))))

(ert-deftest pro/exwm-does-not-start-non-exwm ()
  "В не-EXWM-сессии ничего не стартует."
  (let (pro-exwm-test--wm-called
        pro-exwm-test--tray-called
        pro-exwm-test--xim-called)
    (pro-exwm-test--with-exwm-mocks
      (setenv "XDG_CURRENT_DESKTOP" "GNOME")
      (unwind-protect
          (progn
            (pro-exwm-start-session)
            (should (null pro-exwm-test--wm-called))
            (should (null pro-exwm-test--tray-called))
            (should (null pro-exwm-test--xim-called)))
        (setenv "XDG_CURRENT_DESKTOP" nil)))))

(ert-deftest pro/exwm-starts-with-gdm-prefix ()
  "GDM добавляет префикс none+ — EXWM должен стартовать."
  (let (pro-exwm-test--wm-called
        pro-exwm-test--tray-called
        pro-exwm-test--xim-called)
    (pro-exwm-test--with-exwm-mocks
      (setenv "XDG_CURRENT_DESKTOP" "none+exwm")
      (unwind-protect
          (progn
            (pro-exwm-start-session)
            (should (equal pro-exwm-test--wm-called 1)))
        (setenv "XDG_CURRENT_DESKTOP" nil)))))