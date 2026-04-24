;;; pro-consult-helpers.el --- Малые helper'ы для consult и родственных пакетов -*- lexical-binding: t; -*-
;;
;; Этот модуль предоставляет небольшие адаптеры/обёртки вокруг функций
;; из пакета `consult` чтобы улучшить поведение в окружениях с EXWM,
;; tab-bar и нестандартными workflow. Функции написаны аккуратно и
;; документированы по-русски — цель кода одновременно работать и учить.
;;
;; Public API:
;; - pro/consult-buffer
;; - pro/consult-buffer-other-window
;; - pro/consult-find
;;
;; Внутренние зависимости: consult (загружается лениво), tab-bar, exwm.

(require 'cl-lib)

(defun pro/consult-buffer ()
  "Interactive buffer selection aware of EXWM and tab-bar.
If buffer is visible in a window showing an EXWM buffer, select that window;
otherwise try to switch to a tab that shows the buffer, preserving the
original tab when not found. Falls back to `consult-buffer` behaviour.
This implementation is intentionally small and defensive: it calls
`consult--read` only when consult is present." 
  (interactive)
  (if (not (and (require 'consult nil t) (fboundp 'consult--read)))
      (call-interactively #'consult-buffer)
    (let* ((buf-name (consult--read (mapcar #'buffer-name (buffer-list))
                                    :prompt "Buffer: "
                                    :require-match t
                                    :category 'buffer))
           (buf (get-buffer buf-name)))
      (if (and (get-buffer-window buf 'visible)
               (with-current-buffer buf (derived-mode-p 'exwm-mode)))
          (select-window (get-buffer-window buf 'visible))
        (if (with-current-buffer buf (derived-mode-p 'exwm-mode))
            (let* ((orig-tab (1+ (tab-bar--current-tab-index)))
                   (tabs (tab-bar-tabs))
                   tab-found)
              (cl-loop for i from 1 to (length tabs) do
                       (unless (= i orig-tab)
                         (tab-bar-select-tab i)
                         (when (get-buffer-window buf 'visible)
                           (setq tab-found t)
                           (cl-return))))
              (unless tab-found
                (tab-bar-select-tab orig-tab))
              (switch-to-buffer buf)
          (switch-to-buffer buf)))))))

(defun pro/consult-buffer-other-window ()
  "Open buffer from consult-buffer in a new window with alternating splits.
Alternates between right and below splits depending on the current number
of windows to reduce cognitive friction when opening many buffers." 
  (interactive)
  (let* ((window-count (length (window-list)))
         (split-right-p (= 1 (% window-count 2)))
         target-window)
    (setq target-window
          (if split-right-p
              (split-window-right)
            (split-window-below)))
    (select-window target-window)
    (call-interactively #'consult-buffer)))

(provide 'pro-consult-helpers)

;;; pro-consult-helpers.el ends here

;; A small wrapper around consult-find to set a sensible starting directory.
;; The problem reported: C-x C-f runs consult-find but finds no files — often
;; consult-find is invoked with an empty default-directory or a directory that
;; is ignored by the configured find program. We choose a heuristic: if the
;; project root is available use it; otherwise fall back to default-directory.
;; `pro/consult-find' must be compatible with calls coming from remap of
;; `find-file' which may pass a filename string argument. To avoid "wrong
;; argument" errors we accept an optional argument: if a string is supplied
;; treat it as a filename and delegate to `find-file'. Otherwise invoke
;; `consult-find' starting from the project root (if available) or
;; `default-directory'.
(defun pro/consult-find (&optional arg)
  "Wrapper around `consult-find' that prefers the project root.

If ARG is a string, call `find-file' with ARG (behaviour compatible with
`find-file'). Otherwise call `consult-find' with the project root or
`default-directory'."
  (interactive)
  (cond
   ((and arg (stringp arg))
    (find-file arg))
   (t
    (let ((start (or (and (fboundp 'pro-project-root) (pro-project-root)) default-directory)))
      (if (and (require 'consult nil t) (fboundp 'consult-find))
          ;; Prefer consult-find but fall back to consult-ripgrep when the
          ;; configured backend (fd/find) is not available or returns
          ;; nothing quickly. Use a quick heuristic: if `executable-find` for
          ;; fd or find returns nil, prefer `consult-ripgrep` which uses rg.
          (if (or (executable-find "fd") (executable-find "find"))
              (consult-find start)
          (when (fboundp 'consult-ripgrep)
              (consult-ripgrep start)))
        (call-interactively #'find-file))))))


(provide 'pro-consult-helpers)

;;; pro-consult-helpers.el ends here
