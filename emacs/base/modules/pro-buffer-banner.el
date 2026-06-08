;;; pro-buffer-banner.el --- Transient top banner for buffer/project/branch -*- lexical-binding: t; -*-
;;
;; Show a small, contrasty child frame at the top of the selected window when
;; the user switches buffers or windows. The frame:
;;   - is created ONCE and reused on every show (no flicker, no jumps),
;;   - does not accept input (no focus steal, no click capture),
;;   - fades out automatically after a configurable duration,
;;   - is a true lightweight popup: no title, no tabs, no tool/menu bars,
;;   - degrades gracefully outside of GUI Emacs.
;;
;; Public hooks: `pro-buffer-banner-mode' (interactive toggle).
;; Watcher: `post-command-hook' + a small debounce timer.
;;
;; Dependencies: none strictly required. `pro-project-root' and magit are
;; probed at runtime, so the module still loads in headless/minimal setups.

;; ---------------------------------------------------------------------------
;; Customization
;; ---------------------------------------------------------------------------

(defgroup pro-buffer-banner nil
  "Transient top banner showing buffer/project/branch on switch."
  :group 'pro)

(defcustom pro-buffer-banner-enable t
  "Non-nil to enable the transient buffer banner."
  :type 'boolean :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-duration 1.6
  "Total seconds the banner stays visible (including fade-out)."
  :type 'number :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-fade-steps 10
  "Number of discrete steps in the fade-out animation."
  :type 'integer :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-fade-step-ms 50
  "Milliseconds between fade steps."
  :type 'integer :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-margin-top 8
  "Pixel margin from the top of the selected window."
  :type 'integer :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-show-project t
  "Show project name (via `pro-project-root') in the banner."
  :type 'boolean :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-show-branch t
  "Show VCS branch (magit or vc) in the banner."
  :type 'boolean :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-debounce 0.10
  "Minimum seconds between successive banners. Prevents flicker."
  :type 'number :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-initial-alpha 95
  "Frame alpha (0-100) when the banner appears."
  :type 'integer :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-pad-chars 0
  "Number of blank chars to pad around the text on each side."
  :type 'integer :group 'pro-buffer-banner)

(defface pro-buffer-banner-face
  '((t :foreground "#ffffff" :background "#222222" :weight bold
       :extend t))
  "Face for the banner text. `:extend t' makes the background fill the
whole window/line so no default-colored padding shows around the text."
  :group 'pro-buffer-banner)

;; ---------------------------------------------------------------------------
;; Internal state
;; ---------------------------------------------------------------------------

(defvar pro-buffer-banner--frame nil
  "The single persistent banner child frame, or nil when not yet created.")

(defvar pro-buffer-banner--timer nil
  "Active fade-out timer, or nil.")

(defvar pro-buffer-banner--last-buf nil
  "Last buffer that triggered the banner. Used for change detection.")

(defvar pro-buffer-banner--last-win nil
  "Last window that triggered the banner. Used for change detection.")

(defvar pro-buffer-banner--last-shown-at 0.0
  "Float time of the last banner display; used for debouncing.")

(defvar pro-buffer-banner--bufname nil
  "Name of the buffer backing the banner. Computed from the parent frame.")

;; Quiet the byte-compiler about decoration vars that may not be
;; bound in older Emacsen.
(defvar window-divider) (defvar window-divider-width)
(defvar right-divider-width) (defvar left-divider-width)
(defvar tool-bar-format) (defvar tab-bar-format)

;; ---------------------------------------------------------------------------
;; Helpers
;; ---------------------------------------------------------------------------

(defun pro-buffer-banner--branch ()
  "Best-effort VCS branch name for `default-directory', or nil."
  (or (ignore-errors (and (fboundp 'magit-get-current-branch)
                          (magit-get-current-branch)))
      (ignore-errors (vc-branch))))

(defun pro-buffer-banner--project-name ()
  "Return project display name, or nil when no project / disabled."
  (when pro-buffer-banner-show-project
    (let ((root (and (fboundp 'pro-project-root) (pro-project-root))))
      (when (and root (stringp root) (not (string= root "")))
        (file-name-nondirectory (directory-file-name root))))))

(defun pro-buffer-banner--compose-text (buffer)
  "Compose the banner text for BUFFER."
  (let* ((bname (buffer-name buffer))
         (proj  (pro-buffer-banner--project-name))
         (branch (and pro-buffer-banner-show-branch
                      (pro-buffer-banner--branch)))
         (parts (delq nil
                      (list bname
                            (and proj (format "[%s]" proj))
                            (and branch (format "(%s)" branch))))))
    (string-join parts "  ")))

(defun pro-buffer-banner--bufname ()
  "Return the name of the buffer backing the banner, creating it lazily."
  (or pro-buffer-banner--bufname
      (setq pro-buffer-banner--bufname
            (format " *pro-buffer-banner-%s*"
                    (or (frame-parameter (selected-frame) 'name) "f")))))

;; ---------------------------------------------------------------------------
;; Geometry & frame parameters
;; ---------------------------------------------------------------------------

(defun pro-buffer-banner--compute-geometry (win text)
  "Return a plist with :x :y :w-chars :h-chars for a banner showing TEXT above WIN."
  (let* ((parent (selected-frame))
         ;; Position in pixels
         (left 0) (top 0) (right 0))
    (when (fboundp 'window-pixel-edges)
      (let ((edges (window-pixel-edges win)))
        (setq left  (or (nth 0 edges) 0)
              top   (or (nth 1 edges) 0)
              right (or (nth 2 edges) left))))
    ;; Width in characters: pad + text + pad.
    (let* ((text-len (length text))
           (pad (max 0 pro-buffer-banner-pad-chars))
           (w-chars (+ text-len pad pad))
           (h-chars 1)
           (parent-pixel-w (max 1 (- right left)))
           (char-w (max 1 (frame-char-width parent)))
           (frame-pixel-w (* w-chars char-w))
           ;; Center horizontally in the parent window; clamp so we never
           ;; draw past the window edges.
           (x-raw (+ left (max 0 (/ (- parent-pixel-w frame-pixel-w) 2))))
           (x (min x-raw (max left (- right frame-pixel-w))))
           (y (+ top pro-buffer-banner-margin-top)))
      (list :x x :y y
            :w-chars w-chars :h-chars h-chars
            :parent parent))))

(defun pro-buffer-banner--frame-params (geom)
  "Build a minimal, popup-only frame parameter alist for the banner frame."
  (let ((parent (plist-get geom :parent))
        (x (plist-get geom :x))
        (y (plist-get geom :y))
        (w (plist-get geom :w-chars))
        (h (plist-get geom :h-chars)))
    `((parent-frame . ,parent)
      (left . ,x)
      (top . ,y)
      ;; width/height are in CHARACTERS, not pixels.
      (width . ,w)
      (height . ,h)
      (minibuffer . nil)
      ;; WM-level: no decorations, no taskbar entry, bypass WM focus.
      (undecorated . t)
      (override-redirect . t)
      (no-accept-focus . t)
      (no-focus-on-map . t)
      (no-other-frame . t)
      (skip-taskbar . t)
      (unsplittable . t)
      (visibility . nil)
      (alpha . ,pro-buffer-banner-initial-alpha)
      (mouse-wheel-frame . nil)
      ;; Wipe any text the WM might render on the title bar.
      (title . "")
      (name . "")
      (icon-name . "")
      ;; No internal padding/borders/scrollbars.
      (internal-border-width . 0)
      (fringe . 0)
      (right-fringe . 0)
      (left-fringe . 0)
      (scroll-bar-width . 0)
      (vertical-scroll-bars . nil)
      (horizontal-scroll-bars . nil)
      (tab-bar-lines . 0)
      (tool-bar-lines . 0)
      (menu-bar-lines . 0)
      (tab-bar-format . nil)
      (tool-bar-format . nil)
      (window-divider . nil)
      (window-divider-width . 0)
      (line-spacing . 0)
      ,@(when (assq 'child-frame-border-width (frame-parameters parent))
          '((child-frame-border-width . 0))))))

(defun pro-buffer-banner--strip-decoration (frame)
  "Make FRAME look like a bare label. All changes are FRAME-LOCAL — they
must NOT touch the parent frame's `tab-bar-mode', `tool-bar-mode', etc.,
because those are global modes that would affect every frame."
  (when (frame-live-p frame)
    ;; Frame-local parameters (do not use `tab-bar-mode 0' etc. — those are
    ;; global toggles and would hide bars on the main frame too).
    (set-frame-parameter frame 'line-spacing 0)
    (set-frame-parameter frame 'default-line-spacing 0)
    (set-frame-parameter frame 'tab-bar-lines 0)
    (set-frame-parameter frame 'tool-bar-lines 0)
    (set-frame-parameter frame 'menu-bar-lines 0)
    (set-frame-parameter frame 'name "")
    (set-frame-parameter frame 'title "")
    (set-frame-parameter frame 'icon-name "")
    (with-selected-frame frame
      (setq mode-line-format nil
            header-line-format nil
            tab-line-format nil
            tab-bar-format nil
            tool-bar-format nil)
      (when (boundp 'window-divider)
        (setq window-divider nil
              window-divider-width 0
              right-divider-width 0
              left-divider-width 0)))))

;; ---------------------------------------------------------------------------
;; Single persistent frame
;; ---------------------------------------------------------------------------

(defun pro-buffer-banner--ensure-frame (params)
  "Return the banner frame, creating it with PARAMS only if it doesn't exist."
  (if (frame-live-p pro-buffer-banner--frame)
      pro-buffer-banner--frame
    (condition-case err
        (let ((f (make-frame params)))
          (pro-buffer-banner--strip-decoration f)
          ;; Hide it after creation; we'll show explicitly on each switch.
          (set-frame-parameter f 'visibility nil)
          (setq pro-buffer-banner--frame f)
          f)
      (error
       (message "[pro-buffer-banner] frame create failed: %S" err)
       nil))))

(defun pro-buffer-banner--hide ()
  "Hide the banner frame (without deleting it) and cancel any fade."
  (when (and pro-buffer-banner--timer (timerp pro-buffer-banner--timer))
    (cancel-timer pro-buffer-banner--timer))
  (setq pro-buffer-banner--timer nil)
  (when (frame-live-p pro-buffer-banner--frame)
    (set-frame-parameter pro-buffer-banner--frame 'visibility nil)))

(defun pro-buffer-banner--destroy ()
  "Permanently delete the banner frame. Idempotent."
  (pro-buffer-banner--hide)
  (let ((f pro-buffer-banner--frame))
    (when (frame-live-p f)
      (ignore-errors (redirect-frame-focus f nil))
      (delete-frame f)))
  (setq pro-buffer-banner--frame nil))

;; ---------------------------------------------------------------------------
;; Buffer content
;; ---------------------------------------------------------------------------

(defun pro-buffer-banner--populate (text width-chars)
  "Replace current-buffer contents with TEXT padded to WIDTH-CHARS and styled."
  (let ((inhibit-read-only t)
        (inhibit-modification-hooks t)
        (pad (max 0 (- width-chars (length text)))))
    (erase-buffer)
    (insert (propertize text 'face 'pro-buffer-banner-face))
    (when (> pad 0)
      (insert (propertize (make-string pad ?\s) 'face 'pro-buffer-banner-face)))
    (setq-local cursor-type nil)
    (setq-local window-size-fixed t)
    (setq-local mode-line-format nil)
    (setq-local header-line-format nil)
    (setq-local line-spacing 0)))

;; ---------------------------------------------------------------------------
;; Fade animation
;; ---------------------------------------------------------------------------

(defun pro-buffer-banner--start-fade ()
  "Start the alpha fade-out for the current banner frame."
  (when (and pro-buffer-banner--timer (timerp pro-buffer-banner--timer))
    (cancel-timer pro-buffer-banner--timer))
  (let* ((frame pro-buffer-banner--frame)
         (steps (max 1 pro-buffer-banner-fade-steps))
         (initial pro-buffer-banner-initial-alpha)
         (step 0)
         (step-ms (max 16 pro-buffer-banner-fade-step-ms)))
    (setq pro-buffer-banner--timer
          (run-at-time
           nil step-ms
           (lambda ()
             (cond
              ((not (frame-live-p frame))
               (setq pro-buffer-banner--timer nil))
              ((>= step steps)
               (set-frame-parameter frame 'visibility nil)
               (setq pro-buffer-banner--timer nil))
              (t
               (let* ((frac (/ (float (- steps step)) (float steps)))
                      (a (max 0 (min 100 (round (* frac initial))))))
                 (set-frame-parameter frame 'alpha a))
               (setq step (1+ step)))))))))

;; ---------------------------------------------------------------------------
;; Show
;; ---------------------------------------------------------------------------

(defun pro-buffer-banner--show ()
  "Show the banner for the current buffer in the selected window."
  (when (and pro-buffer-banner-enable
             (display-graphic-p)
             (not noninteractive)
             (frame-live-p (selected-frame))
             (window-live-p (selected-window)))
    (condition-case err
        (let* ((win (selected-window))
               (buf (window-buffer win))
               (text (pro-buffer-banner--compose-text buf))
               (geom (pro-buffer-banner--compute-geometry win text))
               (params (pro-buffer-banner--frame-params geom))
               (width-chars (plist-get geom :w-chars))
               (bufname (pro-buffer-banner--bufname))
               (frame (pro-buffer-banner--ensure-frame params)))
          (when frame
            ;; 1. Update text in-place (no recreation).
            (let ((b (get-buffer-create bufname)))
              (with-current-buffer b
                (pro-buffer-banner--populate text width-chars))
              ;; 2. Attach buffer to the banner window if needed.
              (unless (eq (window-buffer (frame-selected-window frame)) b)
                (save-selected-window
                  (select-frame frame)
                  (set-window-buffer (selected-window) b))))
            ;; 3. Apply geometry in one shot.
            (set-frame-parameter frame 'left (plist-get geom :x))
            (set-frame-parameter frame 'top  (plist-get geom :y))
            (set-frame-parameter frame 'width  width-chars)
            (set-frame-parameter frame 'height (plist-get geom :h-chars))
            ;; 4. Show with full alpha, then start fade.
            (set-frame-parameter frame 'alpha pro-buffer-banner-initial-alpha)
            (set-frame-parameter frame 'visibility t)
            (pro-buffer-banner--start-fade)
            (setq pro-buffer-banner--last-shown-at (float-time))))
      (error
       (message "[pro-buffer-banner] show failed: %S" err)
       (pro-buffer-banner--destroy)))))

(defun pro-buffer-banner--maybe-show ()
  "Watcher invoked from `post-command-hook'. Show the banner on change."
  (when (and pro-buffer-banner-enable
             (display-graphic-p)
             (not noninteractive))
    (let* ((buf (current-buffer))
           (win (selected-window))
           (now (float-time))
           (changed (or (not (eq buf pro-buffer-banner--last-buf))
                        (not (eq win pro-buffer-banner--last-win)))))
      (when (and changed
                 (not (minibufferp buf))
                 (not (window-minibuffer-p win))
                 (window-live-p win)
                 (frame-live-p (window-frame win))
                 (>= (- now pro-buffer-banner--last-shown-at)
                     pro-buffer-banner-debounce))
        (setq pro-buffer-banner--last-buf buf
              pro-buffer-banner--last-win win)
        (pro-buffer-banner--show)))))

;; ---------------------------------------------------------------------------
;; Mode + lifecycle
;; ---------------------------------------------------------------------------

(defun pro-buffer-banner--install ()
  "Install the watcher hook. Idempotent."
  (unless (memq #'pro-buffer-banner--maybe-show post-command-hook)
    (add-hook 'post-command-hook #'pro-buffer-banner--maybe-show 90)))

(defun pro-buffer-banner--uninstall ()
  "Uninstall the watcher hook and tear down any visible banner."
  (remove-hook 'post-command-hook #'pro-buffer-banner--maybe-show)
  (pro-buffer-banner--destroy))

(defun pro-buffer-banner-mode (&optional arg)
  "Toggle the transient buffer banner.
With a prefix ARG, enable when ARG is positive, disable when zero/negative.
Plain `M-x pro-buffer-banner-mode' toggles."
  (interactive
   (list (if current-prefix-arg (prefix-numeric-value current-prefix-arg)
           'toggle)))
  (setq pro-buffer-banner-enable
        (cond
         ((eq arg 'toggle) (not pro-buffer-banner-enable))
         ((null arg)       (not pro-buffer-banner-enable))
         ((numberp arg)    (> arg 0))
         (t                t)))
  (if pro-buffer-banner-enable
      (pro-buffer-banner--install)
    (pro-buffer-banner--uninstall))
  (message "[pro-buffer-banner] %s"
           (if pro-buffer-banner-enable "enabled" "disabled")))

;; Auto-enable when loaded if the user hasn't disabled it.
(when pro-buffer-banner-enable
  (pro-buffer-banner--install))

(provide 'pro-buffer-banner)

;;; pro-buffer-banner.el ends here
