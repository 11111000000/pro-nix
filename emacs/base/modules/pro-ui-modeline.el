;;; pro-ui-modeline.el --- Minimal modeline and optional integrations -*- lexical-binding: t; -*-

(defgroup pro-ui-modeline nil
  "Modeline settings for pro UI"
  :group 'pro-ui)

(defcustom pro-ui-modeline-style 'shaoline
  "Modeline style: 'minimal, 'shaoline or 'doom. Defaults to 'shaoline.
The implementation will attempt to enable the selected modeline
package if available. If not available, a small builtin polish is used." 
  :type '(choice (const minimal) (const shaoline) (const doom))
  :group 'pro-ui-modeline)

(defun pro-ui--enable-shaoline-if-available ()
  "Enable shaoline if present and configured." 
  (when (and (eq pro-ui-modeline-style 'shaoline) (require 'shaoline nil t))
    (with-eval-after-load 'shaoline
      (when (fboundp 'shaoline-mode) (shaoline-mode 1)))))

(defun pro-ui--enable-doom-if-available ()
  "Enable doom-modeline if requested and available." 
  (when (and (eq pro-ui-modeline-style 'doom) (require 'doom-modeline nil t))
    (with-eval-after-load 'doom-modeline
      (when (fboundp 'doom-modeline-mode) (doom-modeline-mode 1)))))

(defun pro-ui-apply-modeline ()
  "Apply modeline according to `pro-ui-modeline-style'." 
  (cond
   ((eq pro-ui-modeline-style 'shaoline) (pro-ui--enable-shaoline-if-available))
   ((eq pro-ui-modeline-style 'doom) (pro-ui--enable-doom-if-available))
   (t ;; minimal polish: reduce clutter, keep essential segments
    (setq-default mode-line-format
                  '((:eval (format " %s" (or (buffer-name) ""))))))))

(provide 'pro-ui-modeline)
