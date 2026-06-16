;;; pro-app-launcher.el --- XDG .desktop launcher (consult-based, EXWM-friendly) -*- lexical-binding: t; -*-
;; Контракт:
;;   Публичные команды: pro/app-launcher.
;;   Зависимости: consult (через `consult--read'). Если consult недоступен —
;;     graceful fallback на `completing-read'.
;;   Поведение: после запуска приложения возвращает фокус EXWM-фрейму, чтобы
;;     новое X-окно гарантированно получило фокус и поднялось над Emacs.
;;
;; Заметка: в современном consult (>= 1.0) команда `counsel-linux-app' из
;; старого `counsel' отсутствует — реализуем свой минимум здесь, без
;; внешних зависимостей сверх consult.
;;
;; Last reviewed: 2026-06-08

(require 'subr-x)

(defcustom pro-app-launcher-directories
  (let ((home (or (and (getenv "XDG_DATA_HOME")
                       (expand-file-name (getenv "XDG_DATA_HOME")))
                  (expand-file-name "~/.local/share")))
        (data-dirs (or (and (getenv "XDG_DATA_DIRS")
                            (parse-colon-path (getenv "XDG_DATA_DIRS")))
                       '("/usr/local/share" "/usr/share"))))
    (mapcar (lambda (d) (expand-file-name "applications" d))
            (cons home data-dirs)))
  "Каталоги поиска *.desktop-файлов (XDG_DATA_DIRS/applications)."
  :type '(repeat directory)
  :group 'pro)

(defvar pro-app-launcher--cache nil
  "Alist (id . file-path) известных .desktop-файлов.")
(defvar pro-app-launcher--cache-stamp nil
  "Время (как в `current-time') последнего построения кэша.")

(defun pro-app-launcher--scan-files ()
  "Пересканировать XDG-каталоги и вернуть свежий alist (id . file)."
  (let ((hash (make-hash-table :test #'equal))
        result)
    (dolist (dir pro-app-launcher-directories)
      (when (file-directory-p dir)
        (dolist (file (ignore-errors
                        (directory-files-recursively dir "\\.desktop\\'")))
          (let ((id (subst-char-in-string ?/ ?-
                                         (file-relative-name file dir))))
            (unless (gethash id hash)
              (push (cons id file) result)
              (puthash id file hash))))))
    result))

(defun pro-app-launcher--parse (file)
  "Распарсить .desktop-файл FILE, вернуть (NAME . FILE) для completing или nil.
Игнорирует записи с `Hidden=1', `NoDisplay=1' или без `Exec='."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((start (re-search-forward "^\\[Desktop Entry\\] *$" nil t))
          (end (re-search-forward "^\\[" nil t))
          (visible t)
          name exec)
      (when start
        (setq end (or end (point-max)))
        (goto-char start)
        (when (re-search-forward "^\\(Hidden\\|NoDisplay\\) *= *\\(1\\|true\\) *$" end t)
          (setq visible nil))
        (goto-char start)
        (when (and visible (re-search-forward "^Type *= *Application *$" end t))
          (goto-char start)
          (when (re-search-forward "^Name *= *\\(.+\\)$" end t)
            (setq name (match-string 1)))
          (goto-char start)
          (when (re-search-forward "^Exec *= *\\(.+\\)$" end t)
            (setq exec (match-string 1))))
        (when (and name exec visible)
          (cons name file))))))

(defun pro-app-launcher--candidates ()
  "Вернуть список (NAME . ID) готовых к запуску приложений."
  (unless (and pro-app-launcher--cache-stamp
               (time-less-p pro-app-launcher--cache-stamp
                            (current-time)))
    (setq pro-app-launcher--cache (pro-app-launcher--scan-files)
          pro-app-launcher--cache-stamp (current-time)))
  (delq nil (mapcar (lambda (entry)
                      (let ((parsed (pro-app-launcher--parse (cdr entry))))
                        (when parsed
                          ;; Сохраняем file в текст-свойстве id для запуска.
                          (cons (car parsed) (cdr entry)))))
                    pro-app-launcher--cache)))

(defun pro-app-launcher--launch (file)
  "Запустить .desktop-файл FILE. Приоритет: gtk-launch, иначе Exec= через shell."
  (let* ((exec (with-temp-buffer
                 (insert-file-contents file)
                 (goto-char (point-min))
                 (when (re-search-forward "^Exec *= *\\(.+\\)$" nil t)
                   (match-string 1)))))
    (cond
     ((null exec)
      (message "pro-app-launcher: Exec= не найден в %s" file))
     ((executable-find "gtk-launch")
      (call-process "gtk-launch" nil 0 nil (file-name-base file)))
     (t
      ;; Вычищаем field-codes ( %f, %u, %F, %U, ... ) и запускаем через shell.
      (let ((cmd (replace-regexp-in-string "%[a-zA-Z]" "" exec)))
        (call-process-shell-command cmd nil 0))))))

(defun pro/app-launcher ()
  "Запуск .desktop-приложения по выбору (Alt-F2 для EXWM)."
  (interactive)
  (let* ((candidates (pro-app-launcher--candidates))
         (choice
          (cond
           ((null candidates)
            (message "pro-app-launcher: .desktop-файлы не найдены в %S"
                     pro-app-launcher-directories)
            nil)
           ((and (require 'consult nil t) (fboundp 'consult--read))
            ;; `consult--read' (как и `completing-read' для alist) возвращает
            ;; уже ЗНАЧЕНИЕ (cdr ячейки (name . file)), то есть строку-путь.
            ;; Раньше мы пытались сделать (cdr choice), что для строки
            ;; вызывало "Wrong type argument: listp" и "apply: Command
            ;; attempted to use minibuffer while in minibuffer".
            (consult--read candidates
                           :prompt "App: "
                           :require-match t
                           :category 'app-launcher
                           :history 'pro-app-launcher-history))
           (t
            (let ((strs (mapcar #'car candidates)))
              (cdr (assoc (completing-read "App: " strs nil t nil
                                           'pro-app-launcher-history)
                          candidates)))))))
    (when choice
      (pro-app-launcher--launch choice)
      ;; Возвращаем фокус X-фрейму через 150 мс — этого хватает, чтобы
      ;; WM поднял новое окно над Emacs.
      (when (fboundp 'x-focus-frame)
        (run-with-timer 0.15 nil
                        (lambda ()
                          (ignore-errors (x-focus-frame (selected-frame)))))))))

(provide 'pro-app-launcher)

;;; pro-app-launcher.el ends here
