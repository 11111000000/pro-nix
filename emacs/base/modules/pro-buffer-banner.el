;;; pro-buffer-banner.el --- transient top banner showing buffer name -*- lexical-binding: t; -*-
;;
;; Show a small, contrasty child frame at the top of the selected window when
;; the user switches buffers/windows. The frame does not accept input and
;; fades out automatically.
;;
;; Minimal, dependency-free implementation using child frames and timers so it
;; works in a GUI Emacs without modifying input focus.

(defgroup pro-buffer-banner nil
  "Transient top banner showing buffer/project/branch on switch." :group 'pro)

(defcustom pro-buffer-banner-enable t
  "Enable the transient buffer banner." :type 'boolean :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-duration 1.2
  "Seconds the banner remains visible before fading out." :type 'number :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-fade-steps 8
  "Number of fade steps when hiding the banner." :type 'integer :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-margin 8
  "Pixel margin from the top and sides for the banner frame." :type 'integer :group 'pro-buffer-banner)

(defface pro-buffer-banner-face
  '((t :foreground "#ffffff" :background "#222222" :weight bold))
  "Face for the banner text." :group 'pro-buffer-banner)

(defvar pro-buffer-banner--frame nil "Currently shown banner child frame.")
(defvar pro-buffer-banner--timer nil "Timer used for fading/removal.")
(defvar pro-buffer-banner--last-state nil "(BUFFER WINDOW TIMESTAMP) last seen state.")

(defun pro-buffer-banner--get-branch ()
  "Return current VCS branch name for `default-directory' or nil.
Try magit then vc-branch."
  (or (and (fboundp 'magit-get-current-branch) (ignore-errors (magit-get-current-branch)))
      (ignore-errors (vc-branch))))

(defun pro-buffer-banner--frame-delete ()
  "Remove banner frame and cancel timers."
  (when (and pro-buffer-banner--timer (timerp pro-buffer-banner--timer))
    (cancel-timer pro-buffer-banner--timer))
  (setq pro-buffer-banner--timer nil)
  (when (frame-live-p pro-buffer-banner--frame)
    (delete-frame pro-buffer-banner--frame))
  (setq pro-buffer-banner--frame nil))

(defun pro-buffer-banner--show ()
  "Create and show the transient banner for the selected window/buffer.
If a banner is already visible, reset its timer and update text."
  (when (and pro-buffer-banner-enable (display-graphic-p))
    (let* ((buf (window-buffer (selected-window)))
           (bname (buffer-name buf))
           (proj (when (fboundp 'pro-project-root) (pro-project-root)))
           (proj-name (when proj (file-name-nondirectory (directory-file-name proj))))
           (branch (pro-buffer-banner--get-branch))
           (text (string-join (delq nil (list bname (when proj-name (format "[%s]" proj-name)) (when branch (format "(%s)" branch)))) " "))
           (edges (window-pixel-edges (selected-window))) ; left top right bottom
           (left (nth 0 edges))
           (top (nth 1 edges))
           (right (nth 2 edges))
           (width-px (- right left))
           (height-px (+ 24))
           (x (+ left pro-buffer-banner-margin))
           (y (+ top pro-buffer-banner-margin))
           (alpha 95)
           (bufname (format " *pro-buffer-banner-%s*" (frame-parameter nil 'name)))
           (frame-params `((parent-frame . ,(selected-frame))
                           (left . ,x)
                           (top . ,y)
                           (width . ,(max 100 (/ width-px (frame-char-width))))
                           (height . 1)
                           (undecorated . t)
                           (no-accept-focus . t)
                           (no-focus-on-map . t)
                           (no-other-frame . t)
                           (skip-taskbar . t)
                           (internal-border-width . 8)
                           (unsplittable . t)
                           (minibuffer . nil)
                           (visibility . t)
                           (alpha . ,alpha))))
      ;; Clean previous
      (pro-buffer-banner--frame-delete)

      (let ((b (get-buffer-create bufname)))
        (with-current-buffer b
          (erase-buffer)
          (insert text)
          (setq-local cursor-type nil)
          (setq-local window-size-fixed t)
          (face-remap-add-relative 'default 'pro-buffer-banner-face))

        (setq pro-buffer-banner--frame (make-frame frame-params))
        ;; Display buffer in the frame's sole window
        (with-selected-frame pro-buffer-banner--frame
          (switch-to-buffer b)
          ;; make window fit text vertically
          (fit-window-to-buffer (selected-window) 1))

        ;; Start fade timer
        (let* ((steps pro-buffer-banner-fade-steps)
               (interval (/ pro-buffer-banner-duration (float steps)))
               (step 0))
          (setq pro-buffer-banner--timer
                (run-at-time interval interval
                             (lambda ()
                               (if (or (not (frame-live-p pro-buffer-banner--frame)) (>= step steps))
                                   (pro-buffer-banner--frame-delete)
                                 (when (frame-live-p pro-buffer-banner--frame)
                                   (setq step (1+ step))
                                   (let* ((frac (/ (float (- steps step)) steps))
                                          (new-alpha (max 0 (floor (* frac alpha)))))
                                     (set-frame-parameter pro-buffer-banner--frame 'alpha new-alpha))))))))))

(defun pro-buffer-banner--maybe-show ()
  "Decide whether to show the banner based on buffer/window changes.
This is throttled to avoid repeated rapid triggers."
  (when pro-buffer-banner-enable
    (let* ((buf (current-buffer))
           (win (selected-window))
           (now (float-time))
           (last pro-buffer-banner--last-state)
           (last-ts (nth 2 last)))
      (unless (or (minibufferp buf)
                  (and last (eq buf (nth 0 last)) (eq win (nth 1 last))))
        (when (or (not last) (> (- now (or last-ts 0)) 0.08))
          (setq pro-buffer-banner--last-state (list buf win now))
          (pro-buffer-banner--show))))))

;; Hook into post-command to detect buffer/window switches. post-command-hook is
;; reliable and available in older Emacs versions; the function itself is cheap.
(when pro-buffer-banner-enable
  (add-hook 'post-command-hook #'pro-buffer-banner--maybe-show))

(provide 'pro-buffer-banner)

;;; pro-buffer-banner.el ends here
