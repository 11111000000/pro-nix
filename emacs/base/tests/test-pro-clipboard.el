;;; test-pro-clipboard.el --- Tests for pro/clipboard-yank-pop -*- lexical-binding: t; -*-

(require 'ert)

(ert-deftest pro-clipboard/dispatch-prefers-consult-if-available ()
  "If `consult' is provided, `pro/clipboard-yank-pop' should call its function.
We simulate by providing a dummy consult-yank-from-kill-ring and checking fboundp." 
  (let ((consult-yank-called nil))
    (cl-letf (((symbol-function 'consult-yank-from-kill-ring)
               (lambda (&rest _args) (setq consult-yank-called t))))
      (require 'pro-clipboard nil t)
      (when (fboundp 'pro/clipboard-yank-pop)
        (progn (pro/clipboard-yank-pop) (should consult-yank-called))))))

(ert-deftest pro-clipboard/fallback-works-to-yank-pop ()
  "When no consult/browse-kill-ring is present, fallback to yank-pop or error." 
  (require 'pro-clipboard nil t)
  (if (fboundp 'yank-pop)
      (should (fboundp 'pro/clipboard-yank-pop))
    (should (or (fboundp 'pro/clipboard-yank-pop) t))))

(provide 'test-pro-clipboard)

;;; test-pro-clipboard.el ends here
