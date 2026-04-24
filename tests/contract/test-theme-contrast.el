;;; test-theme-contrast.el --- ERT tests for theme contrast -*- lexical-binding: t; -*-

(require 'ert)

(defun pro--rgb-luminance (color)
  "Compute approximate luminance of COLOR (string or face color)."
  (let* ((rgb (color-values color))
         (r (/ (float (nth 0 rgb)) 65535.0))
         (g (/ (float (nth 1 rgb)) 65535.0))
         (b (/ (float (nth 2 rgb)) 65535.0)))
    ;; sRGB luminance approximation
    (+ (* 0.2126 r) (* 0.7152 g) (* 0.0722 b))))

(defun pro--contrast-ratio (fg bg)
  "Return approximate contrast ratio between FG and BG color names."
  (let ((l1 (pro--rgb-luminance fg))
        (l2 (pro--rgb-luminance bg)))
    (let ((bright (max l1 l2)) (dark (min l1 l2)))
      (/ (+ bright 0.05) (+ dark 0.05)))))

(ert-deftest pro/theme-default-contrast ()
  "Ensure `default` face foreground/background have acceptable contrast." 
  (let* ((fg (face-attribute 'default :foreground nil 'default))
         (bg (face-attribute 'default :background nil 'default)))
    (should (and fg bg))
    (let ((ratio (pro--contrast-ratio fg bg)))
      ;; Acceptable threshold for small text ~4.5; allow 3.0 as permissive baseline
      (should (>= ratio 3.0)))))

(provide 'test-theme-contrast)

;;; test-theme-contrast.el ends here
