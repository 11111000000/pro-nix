;;; consult-helpers.el --- Small consult helpers and optional features -*- lexical-binding: t; -*-
;; Helper module extracted from ~/pro to provide pro/consult-buffer and related
;; utilities. Loaded lazily by nav.el when consult is available.

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
          (switch-to-buffer buf))))))

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

(provide 'consult-helpers)

;;; consult-helpers.el ends here
