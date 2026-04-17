;;; git.el --- Git workflow -*- lexical-binding: t; -*-

(when (require 'magit nil t)
  (global-set-key (kbd "C-x g") #'magit-status))

(provide 'git)
