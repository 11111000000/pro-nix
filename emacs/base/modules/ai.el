;;; ai.el --- AI helpers -*- lexical-binding: t; -*-

(when (require 'gptel nil t)
  (global-set-key (kbd "C-c a") #'gptel))

(provide 'ai)
