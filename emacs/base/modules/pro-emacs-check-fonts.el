;;; pro-emacs-check-fonts.el --- runtime font/icon availability checks -*- lexical-binding: t; -*-

(defvar pro--required-fonts '("Nerd Font" "DejaVu Sans Mono" "Source Code Pro")
  "Simple list of font family substrings that are recommended for UI icons/text.")

(defun pro--find-font (name)
  "Return t if a font family containing NAME exists in `font-family-list'." 
  (seq-some (lambda (f) (string-match-p (regexp-quote name) f)) (font-family-list)))

(defun pro-emacs-check-fonts (&optional report-buffer)
  "Check for required fonts and print a short report to REPORT-BUFFER (or *Messages*)."
  (let ((missing '()))
    (dolist (f pro--required-fonts)
      (unless (pro--find-font f)
        (push f missing)))
    (if missing
        (message "pro-emacs: missing fonts: %s; falling back to text-only icons" (string-join missing ", "))
      (message "pro-emacs: fonts OK"))))

(provide 'pro-emacs-check-fonts)

;;; pro-emacs-check-fonts.el ends here
