;; emacs-e2e-test.el -- headless collector for *Messages* and *Warnings*
;; Usage: emacs --batch -Q -l emacs-e2e-test.el
;; or:   emacs --batch -l emacs-e2e-test.el  (to load user's init first in test)

(setq debug-on-error t)

(defun write-buffer-if-exists (name out)
  (when-let ((buf (get-buffer name)))
    (with-current-buffer buf
      (write-region (point-min) (point-max) out nil 'silent))))

(let* ((outdir (or (getenv "EMACS_E2E_OUTDIR") "/tmp/emacs-e2e"))
       (mode (or (getenv "EMACS_E2E_MODE") "clean"))) ; "clean" = -Q run, "with-init" = load init
  (make-directory outdir t)
  (message "emacs-e2e: outdir=%s mode=%s" outdir mode)
  ;; Optionally load user init when running with-init:
  (when (string-equal mode "with-init")
    (condition-case err
        (progn
          (message "Loading user init: ~/.emacs.d/init.el")
          (load-file (expand-file-name "~/.emacs.d/init.el")))
      (error (message "Load error: %S" err))))
  ;; Force warnings buffer creation
  (when (not (get-buffer "*Warnings*"))
    (with-temp-buffer (write-region (point-min) (point-max) (concat outdir "/_warnings_placeholder") nil 'silent)))
  ;; Write buffers
  (write-buffer-if-exists "*Messages*" (concat outdir "/Messages.txt"))
  (write-buffer-if-exists "*Warnings*" (concat outdir "/Warnings.txt"))
  ;; Basic failure detection: look for "error" / "Backtrace" / "Unhandled" in Messages
  (let ((messages (when (file-exists-p (concat outdir "/Messages.txt")) (with-temp-buffer (insert-file-contents (concat outdir "/Messages.txt")) (buffer-string)))))
    (when (and messages (string-match-p "\(error\|Backtrace\|Signal\|Unhandled\)" messages))
      (with-temp-file (concat outdir "/FAILED.mark") (insert "failure detected in Messages"))
      (kill-emacs 2)))
  (message "emacs-e2e: finished, outputs in %s" outdir)
  (kill-emacs 0))
