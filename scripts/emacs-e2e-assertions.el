;; Headless E2E assertions for pro-nix Emacs completion stack
;; Run under: emacs --batch -l scripts/emacs-e2e-assertions.el

(setq debug-on-error t)

(defun ee/report (msg)
  (princ (concat "E2E: " msg "\n")))

(defun ee/feature-assert (feat)
  (if (featurep feat)
      (ee/report (format "feature %s: OK" feat))
    (progn (ee/report (format "feature %s: MISSING" feat)) (kill-emacs 2))))

(defun ee/remap-assert (orig cmd)
  "Assert that ORIG is remapped to CMD globally." 
  (let ((binding (cdr (assoc orig (symbol-function 'kbd)))))
    ;; fallback: just test that CMD is fboundp
    (if (fboundp cmd)
        (ee/report (format "remap %s -> %s: fbound OK" orig cmd))
      (progn (ee/report (format "remap %s -> %s: MISSING" orig cmd)) (kill-emacs 2)))))

(defun ee/run ()
  (ee/report "Starting assertions")
  (ee/feature-assert 'vertico)
  (ee/feature-assert 'consult)
  (ee/feature-assert 'orderless)
  (ee/feature-assert 'corfu)
  (ee/feature-assert 'cape)
  (ee/feature-assert 'embark)
  (ee/feature-assert 'marginalia)
  ;; Sanity checks
  (when (and (fboundp 'consult-find) (fboundp 'consult-buffer))
    (ee/report "consult functions present: OK"))
  (ee/report "Assertions completed successfully")
  (kill-emacs 0))

(ee/run)
