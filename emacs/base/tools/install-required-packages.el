;;; install-required-packages.el --- Install packages referenced by pro modules -*- lexical-binding: t; -*-
;; Usage: emacs --batch -l emacs/base/init.el -l emacs/base/tools/install-required-packages.el

(message "install-required: start")

(defun install-required--collect-candidates ()
  "Collect package symbols referenced in pro modules.
Scans for occurrences of pro--package-provided-p, pro-packages--maybe-install and plain require forms.
Returns a list of symbols representing package names to consider for installation." 
  (let ((dir (expand-file-name "emacs/base/modules" (file-name-directory (or load-file-name buffer-file-name))))
        (cands '()))
    (when (file-directory-p dir)
      (dolist (file (directory-files dir t "^pro-.*\\.el$"))
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (while (re-search-forward "pro--package-provided-p\s-+'\([A-Za-z0-9_-]+\)" nil t)
            (let ((sym (intern (match-string 1)))) (push sym cands)))
          (goto-char (point-min))
          (while (re-search-forward "pro-packages--maybe-install\s-+'\([A-Za-z0-9_-]+\)" nil t)
            (let ((sym (intern (match-string 1)))) (push sym cands)))
          (goto-char (point-min))
          (while (re-search-forward "(require\s-+'\([A-Za-z0-9_-]+\)" nil t)
            (let ((sym (intern (match-string 1))))
              ;; ignore internal pro- features
              (unless (string-prefix-p "pro-" (symbol-name sym)) (push sym cands)))))))
    (delete-dups cands)) )

(defun install-required--is-gui-only (pkg)
  "Heuristic: return non-nil if PKG is typically GUI-only (exwm/eldoc-box).
Used to skip in headless installs if desired." 
  (memq pkg '(exwm eldoc-box vterm)))

(let* ((candidates (install-required--collect-candidates))
       (installed '()) (failed '()))
  (message "install-required: candidate packages: %S" candidates)
  (dolist (p candidates)
    (condition-case err
        (progn
          (if (or (pro--package-provided-p p) (pro-packages--maybe-install p t) (require p nil t))
              (progn (push p installed) (message "install-required: available %s" p))
            (progn (push p failed) (message "install-required: missing %s" p))))
      (error (push p failed) (message "install-required: error installing %s: %S" p err))))
  (message "install-required: installed=%S failed=%S" installed failed)
  (when failed
    (message "install-required: Some packages failed to install — check package-archives and network or consider providing via Nix: %S" failed))
  (message "install-required: done")
  (when failed  (kill-emacs 2))
  (kill-emacs 0))
