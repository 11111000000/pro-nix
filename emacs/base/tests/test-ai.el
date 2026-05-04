;;; test-ai.el --- Unit tests for pro-ai auto-load -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defun pro-test-ai--ensure-modules-load-path ()
  "Добавить emacs/base/modules в `load-path', если каталог обнаружим."
  (let* ((start (or load-file-name buffer-file-name default-directory))
         (repo-root (or (locate-dominating-file start ".git")
                        (locate-dominating-file start "emacs")
                        (file-name-directory start))))
    (when repo-root
      (let ((modules-dir (expand-file-name "emacs/base/modules" repo-root)))
        (unless (member modules-dir load-path)
          (add-to-list 'load-path modules-dir))))))

(ert-deftest pro/ai-maybe-auto-load-gptel-loads-when-available ()
  "`pro-ai--maybe-auto-load-gptel' должен вызвать require при доступном gptel."
  (pro-test-ai--ensure-modules-load-path)
  (require 'pro-ai)
  (let ((pro-ai-auto-load-gptel t)
        (after-init-time t)
        (required nil))
    (cl-letf (((symbol-function 'featurep)
               (lambda (sym)
                 (and (eq sym 'gptel) nil)))
              ((symbol-function 'locate-library)
               (lambda (name)
                 (when (string= name "gptel") "dummy/path/gptel.el")))
              ((symbol-function 'require)
               (lambda (feature &optional _filename _noerror)
                 (when (eq feature 'gptel)
                   (setq required t)
                   t))))
      (pro-ai--maybe-auto-load-gptel)
      (should required))))

(ert-deftest pro/ai-maybe-auto-load-gptel-skips-when-disabled ()
  "`pro-ai--maybe-auto-load-gptel' не должен грузить gptel, если опция выключена."
  (pro-test-ai--ensure-modules-load-path)
  (require 'pro-ai)
  (let ((pro-ai-auto-load-gptel nil)
        (after-init-time t)
        (required nil))
    (cl-letf (((symbol-function 'featurep)
               (lambda (sym)
                 (and (eq sym 'gptel) nil)))
              ((symbol-function 'locate-library)
               (lambda (_name) "dummy/path/gptel.el"))
              ((symbol-function 'require)
               (lambda (feature &optional _filename _noerror)
                 (when (eq feature 'gptel)
                   (setq required t)
                   t))))
      (pro-ai--maybe-auto-load-gptel)
      (should-not required))))

(provide 'test-ai)

;;; test-ai.el ends here
