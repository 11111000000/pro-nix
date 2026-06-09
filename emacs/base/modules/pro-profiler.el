;;; pro-profiler.el --- Convenience wrappers for Emacs built-in profiler -*- lexical-binding: t; -*-

;; Назначение: удобные обёртки вокруг profiler.el с возможностью одной
;; клавишей запустить «быструю» сессию профилирования (start → wait N sec →
;; stop → report).
;;
;; Контракт:
;; - Не назначает глобальных биндов. Регистрирует предложения через
;;   `pro/register-module-keys' (canonical bindings — в emacs-keys.org).
;; - `pro/profiler-quick' идемпотентен: повторный вызов во время уже идущей
;;   сессии безопасно прерывает её и запускает новую.
;; - Не вызывает GUI-only функции в headless: profiler-report открывает буфер,
;;   который виден в любом режиме (включая batch при ручном вызове).

(defgroup pro-profiler nil
  "Profiler helpers for pro-emacs." :group 'pro)

(defcustom pro/profiler-quick-duration 15
  "Длительность (сек) автоматической сессии `pro/profiler-quick'."
  :type 'integer
  :group 'pro-profiler)

(defcustom pro/profiler-default-mode 'cpu
  "Режим профилирования по умолчанию для `pro/profiler-start' и
`pro/profiler-quick'. Допустимые значения: `cpu', `mem', `cpu+mem'."
  :type '(choice (const cpu) (const mem) (const cpu+mem))
  :group 'pro-profiler)

(defvar pro/profiler--quick-timer nil
  "Активный таймер `pro/profiler-quick' или nil.")

(defun pro/profiler--running-p ()
  "Возвращает t, если профайлер сейчас запущен (любой режим)."
  (and (fboundp 'profiler-running-p) (profiler-running-p)))

(defun pro/profiler-start (&optional mode)
  "Запустить профайлер в режиме MODE (по умолчанию `pro/profiler-default-mode').
Если профайлер уже запущен — сначала останавливает его."
  (interactive)
  (require 'profiler)
  (when (pro/profiler--running-p)
    (ignore-errors (profiler-stop)))
  (let ((m (or mode pro/profiler-default-mode)))
    (profiler-start m)
    (message "pro/profiler: started (mode=%s)" m)))

(defun pro/profiler-stop ()
  "Остановить профайлер. Не открывает отчёт."
  (interactive)
  (require 'profiler)
  (if (pro/profiler--running-p)
      (progn (profiler-stop) (message "pro/profiler: stopped"))
    (message "pro/profiler: not running")))

(defun pro/profiler-report ()
  "Показать отчёт профайлера (без остановки)."
  (interactive)
  (require 'profiler)
  (call-interactively #'profiler-report))

(defun pro/profiler-reset ()
  "Сбросить накопленные данные профайлера."
  (interactive)
  (require 'profiler)
  (when (fboundp 'profiler-reset) (profiler-reset))
  (message "pro/profiler: reset"))

(defun pro/profiler--quick-finish ()
  "Внутренний колбэк таймера `pro/profiler-quick': stop + report."
  (setq pro/profiler--quick-timer nil)
  (when (pro/profiler--running-p)
    (ignore-errors (profiler-stop)))
  (message "pro/profiler: quick session finished, opening report…")
  (require 'profiler)
  (condition-case err
      (profiler-report)
    (error (message "pro/profiler: report failed: %S" err))))

(defun pro/profiler-quick (&optional seconds)
  "Запустить профайлер, остановить через SECONDS секунд и открыть отчёт.
SECONDS по умолчанию — `pro/profiler-quick-duration'. С префиксом C-u
запросит длительность интерактивно."
  (interactive
   (list (if current-prefix-arg
             (read-number "Profile for seconds: " pro/profiler-quick-duration)
           pro/profiler-quick-duration)))
  (require 'profiler)
  (let ((secs (or seconds pro/profiler-quick-duration)))
    (when (timerp pro/profiler--quick-timer)
      (cancel-timer pro/profiler--quick-timer)
      (setq pro/profiler--quick-timer nil))
    (when (pro/profiler--running-p)
      (ignore-errors (profiler-stop)))
    (profiler-start pro/profiler-default-mode)
    (message "pro/profiler: quick session — %ds (mode=%s), report will open automatically"
             secs pro/profiler-default-mode)
    (setq pro/profiler--quick-timer
          (run-at-time secs nil #'pro/profiler--quick-finish))))

(with-eval-after-load 'pro-keys
  (condition-case _err
      (when (fboundp 'pro/register-module-keys)
        (pro/register-module-keys
         'profiler
         '(("<f8>"     . pro/profiler-quick)
           ("C-<f8>"   . pro/profiler-start)
           ("S-<f8>"   . pro/profiler-stop)
           ("M-<f8>"   . pro/profiler-report)
           ("C-S-<f8>" . pro/profiler-reset))))
    (error (message "pro/profiler: failed to register suggestions"))))

(provide 'pro-profiler)

;;; pro-profiler.el ends here
