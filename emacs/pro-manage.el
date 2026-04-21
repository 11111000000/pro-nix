;;; pro-manage.el --- Простая обёртка для proctl в Emacs  -*- lexical-binding: t; -*-
;;
;; Минимальный Emacs‑клиент для взаимодействия с proctl.
;; Все комментарии и описания на русском.

(require 'json)
(require 'button)

(defvar pro-manage--proctl "./proctl/cli.py" "Путь к proctl CLI")

(defun pro-manage--call (args callback)
  "Выполнить proctl с ARGS асинхронно и вызвать CALLBACK при завершении.
CALLBACK получает один аргумент — распарсенный JSON или alist с :error.")
  (let ((buf (generate-new-buffer "*proctl-temp*")))
    (set-process-sentinel
     (apply #'start-process "proctl" buf pro-manage--proctl args)
     (lambda (proc _)
       (when (= (process-exit-status proc) 0)
         (with-current-buffer buf
           (let ((out (buffer-string)))
             (kill-buffer buf)
             (condition-case err
                 (funcall callback (json-parse-string out :object-type 'alist))
               (error (funcall callback `((:error . "parse-error"))))))))) )))

(defun pro-manage-list-hosts ()
  "Показать список хостов." 
  (interactive)
  (pro-manage--call '("list-hosts")
                     (lambda (res)
                       (if (assoc :error res)
                           (message "Ошибка: %s" (alist-get :error res))
                         (message "hosts: %s" (alist-get 'hosts res))))))

(provide 'pro-manage)
