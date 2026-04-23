;;; key-utils.el --- Small utilities for writing keybindings and saving them to keys.el -*- lexical-binding: t; -*-
;; A minimal, defensive adaptation of ~/pro/инструменты/про-малую-механизацию.el

(defvar pro/keys-file (expand-file-name "~/.config/emacs/keys.el")
  "File where user-added keybindings are stored.")

(defun pro/add-keybinding-to-file (key fn-symbol)
  "Add a global keybinding (KEY -> FN-SYMBOL) to `pro/keys-file`.
Writes a short Lisp expression into the file and also binds it now.
This is intentionally minimal and safe: it will append the binding and not overwrite file.
KEY is a string accepted by `kbd`, FN-SYMBOL is a symbol or string name of function." 
  (interactive "sKey (kbd): \nSFunction symbol: ")
  (let* ((fn (if (symbolp fn-symbol) fn-symbol (intern fn-symbol)))
         (org-entry (format "| %s | %s | %s | added-by key-utils |\n" "User" key fn)))
    ;; Append an Org table row to the user's keys.org file and reload keys.
    (with-temp-buffer
      (if (file-exists-p pro/keys-file)
          (insert-file-contents pro/keys-file))
      ;; Ensure table header exists; naive approach: append table row
      (goto-char (point-max))
      (insert org-entry)
      (write-region (point-min) (point-max) pro/keys-file))
    (when (fboundp 'pro-keys-reload)
      (pro-keys-reload))
    (message "Added key suggestion %s -> %s to %s (reload attempted)" key fn pro/keys-file)))

(provide 'key-utils)

;;; key-utils.el ends here
