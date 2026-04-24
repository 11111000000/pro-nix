;;; startup-metrics.el --- Startup timing helpers for pro-emacs -*- lexical-binding: t; -*-

(defvar pro--startup-metrics '()
  "Alist of startup metrics recorded during Emacs initialization.")

(defun pro--record-metric (name ms)
  "Record metric NAME with value MS (milliseconds)."
  (add-to-list 'pro--startup-metrics (cons name ms)))

(defun pro--measure (name fn)
  "Measure execution time of FN and record metric with NAME.
FN is a zero-arg thunk." 
  (let ((t0 (current-time)))
    (prog1 (funcall fn)
      (let* ((t1 (current-time))
             (diff (float-time (time-subtract t1 t0)))
             (ms (* diff 1000.0)))
        (pro--record-metric name ms)))))

(defun pro--write-metrics (file)
  "Write recorded metrics to FILE as simple alist printed representation." 
  (with-temp-file file
    (prin1 pro--startup-metrics (current-buffer))))

(provide 'startup-metrics)

;;; startup-metrics.el ends here
