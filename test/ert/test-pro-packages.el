;; Русский: комментарии и пояснения оформлены в учебном стиле (пояснения и примеры)
(ert-deftest pro-packages-declarations-loaded ()
  "Ensure pro-packages module loads and decisions are available."
  (let* ((init (expand-file-name "emacs/base/init.el" default-directory)))
    (load-file init)
    (should (featurep 'pro-packages))
    (pro-packages--load-decisions)
    (should (listp pro-packages-decisions))))
