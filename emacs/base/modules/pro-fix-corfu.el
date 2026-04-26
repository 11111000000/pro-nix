;;; pro-fix-corfu.el --- corfu posframe multi-monitor fixes -*- lexical-binding: t; -*-
;; Minor fixes to make Corfu child frames/posframe behave better on
;; multi-monitor setups (adapted from legacy pro configuration).

(defun pro/corfu--monitor-geometry (&optional frame)
  "Return geometry (x y width height) of FRAME's monitor.
If FRAME is nil, use selected frame." 
  (let* ((attrs (frame-monitor-attributes (or frame (selected-frame))))
         (workarea (assoc 'workarea attrs))
         (geom (cdr workarea)))
    ;; `frame-monitor-attributes' may return the workarea in different
    ;; container types depending on platform/Emacs version: a list of 4
    ;; numbers, a vector, or occasionally an unexpected value (number
    ;; or nil). Be defensive: only return a list of four numbers. In
    ;; other cases return nil so callers fall back to default behaviour.
    (cond
     ((and (listp geom) (= (length geom) 4)) geom)
     ((and (vectorp geom) (= (length geom) 4)) (append geom nil))
     (t nil))))

(defun pro/corfu--adjust-child-frame-position (orig-fun &rest args)
  "Advice wrapper around corfu child frame creation to respect monitor geometry.
ORIG-FUN is the original function, ARGS are passed through. We adjust X/Y
coordinates so child frames appear on the focused monitor." 
  (let* ((frame (nth 0 args))
         (x (nth 1 args))
         (y (nth 2 args))
         (w (nth 3 args))
         (h (nth 4 args))
         (mon-geom (pro/corfu--monitor-geometry (selected-frame))))
    (condition-case err
        (if (and mon-geom
                 ;; mon-geom must be a sequence (list or vector) with at least
                 ;; two numeric elements (x and y). Be defensive: do not
                 ;; assume a particular shape returned by the platform.
                 (or (and (listp mon-geom) (>= (length mon-geom) 2))
                     (and (vectorp mon-geom) (>= (length mon-geom) 2)))
                 (numberp (elt mon-geom 0)) (numberp (elt mon-geom 1)))
            (let ((mx (elt mon-geom 0)) (my (elt mon-geom 1)))
              (apply orig-fun frame (+ mx (or x 0)) (+ my (or y 0)) w h))
          (apply orig-fun frame x y w h))
      (error
       ;; If anything goes wrong, fallback to original behaviour and log
       ;; a debug message to help triage platform-specific monitor attrs.
       (message "[pro-fix-corfu] monitor-geometry/advice error: %S (mon-geom=%S)" err mon-geom)
       (apply orig-fun frame x y w h)))))

;; Apply advice when corfu--make-frame exists. Guard to avoid errors on
;; corfu versions that do not use that function or have different signatures.
(with-eval-after-load 'corfu
  (when (fboundp 'corfu--make-frame)
    (advice-add 'corfu--make-frame :around #'pro/corfu--adjust-child-frame-position)))

(provide 'pro-fix-corfu)

;;; pro-fix-corfu.el ends here
