;;; exwm.el --- EXWM session -*- lexical-binding: t; -*;; Этот модуль поднимает EXWM и отдельно регистрирует Super-цифры через
;; `exwm-input-set-key`, чтобы они перехватывались поверх Xorg-окон.

(defvar pro-exwm-session-desktop-name "EXWM"
  "Имя графической сессии, в которой Emacs должен поднять EXWM.")

(defconst pro-exwm-super-tab-keys
  (let ((keys nil))
    (dotimes (i 6)
      (let ((tab (1+ i)))
        (push (cons (kbd (format "s-%d" tab))
                    `(lambda () (interactive) (tab-bar-select-tab ,tab)))
              keys)))
    (nreverse keys))
  "Глобальные клавиши EXWM для переключения вкладок поверх Xorg-окон.")

(defun pro-exwm--apply-global-keys ()
  "Собрать глобальные EXWM-клавиши с учётом базового слоя pro-exwm."
  (when (boundp 'exwm-input-global-keys)
    (setq exwm-input-global-keys
          (append pro-exwm-super-tab-keys
                  (and (boundp 'pro-keys-exwm-global-keys)
                       pro-keys-exwm-global-keys)))))

(defun pro-exwm--session-p ()
  "Проверить, что Emacs запущен как EXWM-сессия." 
  (string= (or (getenv "XDG_CURRENT_DESKTOP") "") pro-exwm-session-desktop-name))

(defun pro-exwm-start-session ()
  "Запустить EXWM для текущей Emacs-сессии, если это EXWM-сеанс." 
  (interactive)
  (when (and (featurep 'exwm)
             (fboundp 'exwm-wm-mode)
             (pro-exwm--session-p))
    (pro-exwm--apply-global-keys)
    (exwm-wm-mode 1)))

(with-eval-after-load 'exwm
  (setq exwm-workspace-number 4)
  (pro-exwm--apply-global-keys)
  (when (featurep 'exwm-systemtray)
    (exwm-systemtray-enable)))

(with-eval-after-load 'pro-keys
  (pro-exwm--apply-global-keys))

(add-hook 'window-setup-hook #'pro-exwm-start-session)

(provide 'pro-exwm)
