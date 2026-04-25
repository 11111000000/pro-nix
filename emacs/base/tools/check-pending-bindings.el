;;; check-pending-bindings.el --- Проверка и попытка применить отложенные биндинги pro-keys
;; Запустить: emacs --batch -l emacs/base/init.el -l emacs/base/tools/check-pending-bindings.el

(message "check-pending: start")

(defun check-pending--candidates-for-command (cmd)
  "Вернуть список candidate features для попытки require по CMD symbol.
Это эвристика: маппим префиксы/имена команд на пакеты, которые обычно
их предоставляют." 
  (let ((s (symbol-name cmd)))
    (cond
     ((string-prefix-p "pro-" s) (list (intern (concat "pro-" (car (split-string (substring s 4) "-")))) 'pro-packages 'pro-core))
     ((string-prefix-p "pro/" s) (list 'pro-consult-helpers 'pro-keys))
     ((string-prefix-p "consult-" s) (list 'consult))
     ((string-prefix-p "cape-" s) (list 'cape))
     ((string-prefix-p "projectile-" s) (list 'projectile))
     ((string-prefix-p "treemacs" s) (list 'treemacs))
     ((string-prefix-p "eglot" s) (list 'eglot))
     ((string-prefix-p "exwm-" s) (list 'exwm))
     ((string-match-p "eldoc" s) (list 'eldoc 'eldoc-box))
     ((string-match-p "expand-region" s) (list 'expand-region))
     (t (list (intern (car (split-string s "-"))) ; try first component as feature
              (intern (concat s))
              )))))

(defun check-pending--try-require (feat)
  "Попытаться require FEAT non-interactively; вернуть t при успехе." 
  (condition-case err
      (progn
        (require feat nil t)
        (featurep feat))
    (error (message "require %s failed: %S" feat err) nil)))

(when (boundp 'pro-keys-pending-bindings)
  (let ((pending (copy-sequence pro-keys-pending-bindings)))
    (message "check-pending: found %d pending entries" (length pending))
    (dolist (entry pending)
      (pcase entry
        (`(:global ,key ,cmd)
         (let ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd)))))
           (message "checking global %s -> %S" key sym)
           (dolist (feat (check-pending--candidates-for-command sym))
             (unless (featurep feat)
               (message " trying require %s" feat)
               (check-pending--try-require feat)))
           (message " fboundp %s => %S" sym (fboundp sym))))
        (`(:exwm ,key ,cmd)
         (let ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd)))))
           (message "checking exwm %s -> %S" key sym)
           (dolist (feat (check-pending--candidates-for-command sym)) (check-pending--try-require feat))
           (message " fboundp %s => %S" sym (fboundp sym))))
        (`(:org ,key ,cmd)
         (let ((sym (if (symbolp cmd) cmd (intern (format "%s" cmd)))))
           (message "checking org %s -> %S" key sym)
           (dolist (feat (check-pending--candidates-for-command sym)) (check-pending--try-require feat))
           (message " fboundp %s => %S" sym (fboundp sym))))
        (_ (message "unknown pending entry: %S" entry))))

    ;; Попробуем применить отложенные привязки ещё раз
    (when (fboundp 'pro-keys-apply-pending)
      (ignore-errors (pro-keys-apply-pending)))

    (message "check-pending: after apply, pending count = %d" (if (boundp 'pro-keys-pending-bindings) (length pro-keys-pending-bindings) 0))
    (when (boundp 'pro-keys-pending-bindings)
      (dolist (e pro-keys-pending-bindings) (message " STILL PENDING: %S" e)))))

(message "check-pending: done")
