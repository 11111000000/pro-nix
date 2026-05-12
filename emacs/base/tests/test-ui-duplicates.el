;;; test-ui-duplicates.el --- Detect duplicate pro-ui feature names -*- lexical-binding: t; -*-

(require 'ert)

(ert-deftest pro-ui-features-are-unique ()
  "Fail if multiple modules provide the same pro-ui feature name.

This test parses files in emacs/base/modules and collects `(provide '...)
forms. If a `provide' symbol appears in more than one file the test fails
with a diagnostic list of duplicates.
"
  (let* ((mods-dir (expand-file-name "emacs/base/modules" (or (and (fboundp 'locate-dominating-file) (locate-dominating-file default-directory ".git")) ".")))
         (files (when (file-directory-p mods-dir) (directory-files mods-dir t "^pro-.*\\.el$")))
         (provides (make-hash-table :test 'equal)))
    (dolist (f files)
      (with-temp-buffer
        (insert-file-contents f)
        (goto-char (point-min))
        (while (re-search-forward "(provide\s+'\([^)]+\))" nil t)
          (let ((sym (match-string 1)) (file f))
            (puthash sym (cons file (gethash sym provides)) provides)))))
    (let (dups)
      (maphash (lambda (k v)
                 (when (> (length v) 1)
                   (push (cons k (reverse v)) dups)))
               provides)
      (when dups
        (ert-fail (format "Duplicate provides found: %S" dups)))))

(provide 'test-ui-duplicates)

;;; test-ui-duplicates.el ends here
