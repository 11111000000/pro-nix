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

(defcustom pro-buffer-banner-duration 3.0
  "Total seconds the banner stays visible (including fade-out).

Banner appears after a buffer/window switch, then stays fully visible
for ~80% of this duration, with a short fade-out at the end. Three
seconds is a comfortable read window for buffer name + project +
branch without becoming intrusive."
  :type 'number :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-fade-steps 10
  "Number of discrete steps in the fade-out animation."
  :type 'integer :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-fade-step-ms 50
  "Milliseconds between fade steps."
  :type 'integer :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-position :bottom
  "Where to show the banner relative to the selected window.
`:top'    — at the top of the window.
`:bottom' — at the bottom of the window."
  :type '(choice (const :tag "Top" :top)
                 (const :tag "Bottom" :bottom))
  :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-margin 4
  "Pixel margin from the window edge (top or bottom, depending on
`pro-buffer-banner-position'). 1px — minimum visible gap, 0 means \"one line
height\" of the parent frame's font (enough to clear the mode-line
or first line of text, but visually too far for an unobtrusive banner).
Default 4px: leaves a clear gap above the mode-line without pushing the
banner out of the window's visible area."
  :type 'integer :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-show-project t
  "Show project name (via `pro-project-root') in the banner."
  :type 'boolean :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-show-branch t
  "Show VCS branch (magit or vc) in the banner."
  :type 'boolean :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-debounce 0.2
  "Minimum seconds between successive *display* calls. This is a pure
display-side throttle, NOT a fade-restart trigger: even if a new
display is allowed by the debounce, the running fade is NOT restarted
(see `pro-buffer-banner--show' for details). The visible time is
therefore always `pro-buffer-banner-duration' from the first display
in a burst, regardless of how many switches happen in between.

Set to 0 to disable the throttle (the banner will re-display on every
post-command / window-selection change). 200ms is enough to suppress
the spammy minibuffer-open/close and rapid C-x b b b switching, while
still letting single switches through immediately."
  :type 'number :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-initial-alpha 95
  "Frame alpha (0-100) when the banner appears."
  :type 'integer :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-pad-chars 2
  "Number of blank chars to pad on the LEFT of the banner text.

The banner's child frame is the *exact* size of the rendered text + this
left padding + `pro-buffer-banner-right-pad-chars' on the right. The
right side gets a separate, larger pad so the dark background fully
covers the mode-line indicators on that side (buffer-identification,
`%p', etc., which would otherwise peek out from behind the banner)."
  :type 'integer :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-right-pad-chars 5
  "Number of blank chars to pad on the RIGHT of the banner text.

The mode-line carries variable-width text on the right (buffer name,
position, mode indicators). With a symmetric pad, the centered banner
ends mid-mode-line and those indicators bleed through. Pushing the
right edge further out keeps the banner's dark background flush with
the right edge of the mode-line content. 5 chars is enough to cover
the right-side indicators without leaving a wide blank gap."
  :type 'integer :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-max-text-chars 80
  "Maximum length of the banner text. If the composed text exceeds this,
it is truncated with a trailing \"...\" so the frame stays narrow and
predictable. Set to 0 to disable truncation."
  :type 'integer :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-font-scale 0.85
  "Scale factor for the banner font relative to the parent frame.
0.85 — close to the parent font but slightly smaller, so the banner
reads at a glance but doesn't compete with the main text. 0.7 used
to be the default but rendered too thin to read comfortably."
  :type 'number :group 'pro-buffer-banner)

(defcustom pro-buffer-banner-theme-aware t
  "Non-nil derives banner colors from the current `default' face.
The banner background is set to the default face's foreground (the
text color of the parent frame) and the banner foreground to the
default face's background (the frame color of the parent frame).
The result is a high-contrast *inverted* banner that adapts to any
theme.

When nil, the colors from `pro-buffer-banner-face' (set via
`M-x customize-face') are used as-is."
  :type 'boolean :group 'pro-buffer-banner)

(defface pro-buffer-banner-face
  `((t :foreground "#ffffff" :background "#222222" :weight bold
       :height ,pro-buffer-banner-font-scale
       :extend t))
  "Face for the banner text. `:extend t' makes the background fill the
whole window/line so no default-colored padding shows around the text.

By default the static white-on-dark colors above are *overridden*
dynamically by `pro-buffer-banner--apply-theme-face' on load and on
every theme change.  The dynamic face inverts the `default' face:
- banner :background = default :foreground
- banner :foreground = default :background
so the banner is always high-contrast against the rest of the
buffer.  The colors shown here are only used as a fallback when
the `default' face has no colors set (e.g. very early in startup
or in a headless test).  Disable the dynamic behavior by setting
`pro-buffer-banner-theme-aware' to nil and customize this face."
  :group 'pro-buffer-banner)

;; ---------------------------------------------------------------------------
;; Theme-aware face
;; ---------------------------------------------------------------------------
;; The banner's background and foreground are derived from the current
;; `default' face (inverted) so the banner is always high-contrast
;; against the rest of the buffer, regardless of the active theme:
;;
;;   banner :background = default :foreground   (the text color of the
;;                                                 parent frame)
;;   banner :foreground = default :background   (the frame color of the
;;                                                 parent frame)
;;
;; Updated on every theme change.  The static colors in the `defface'
;; above are only a fallback for environments where the `default' face
;; has no colors (e.g. very early in Emacs startup or headless tests).

(defun pro-buffer-banner--resolve-default-colors ()
  "Return a cons (FOREGROUND . BACKGROUND) derived from the `default' face.
Falls back to the frame's `background-mode' when the default face's
fg/bg attributes are not specified (e.g. before any theme loads)."
  (let* ((dflt-fg (face-attribute 'default :foreground))
         (dflt-bg (face-attribute 'default :background))
         (bg-mode (frame-parameter nil 'background-mode))
         (fallback-fg (if (eq bg-mode 'dark) "white" "black"))
         (fallback-bg (if (eq bg-mode 'dark) "black" "white"))
         (fg (if (and dflt-fg (stringp dflt-fg)
                      (not (string= dflt-fg "unspecified")))
                 dflt-fg
               fallback-fg))
         (bg (if (and dflt-bg (stringp dflt-bg)
                      (not (string= dflt-bg "unspecified")))
                 dflt-bg
               fallback-bg)))
    (cons fg bg)))

(defun pro-buffer-banner--apply-theme-face ()
  "Recompute `pro-buffer-banner-face' from the current `default' face.

Banner background = default foreground (text color of the parent frame).
Banner foreground = default background (frame color of the parent frame).

The result is a high-contrast *inverted* banner that is always readable
against the rest of the buffer regardless of the active theme.
No-op when `pro-buffer-banner-theme-aware' is nil."
  (when pro-buffer-banner-theme-aware
    (pcase-let ((`(,default-fg . ,default-bg)
                 (pro-buffer-banner--resolve-default-colors)))
      (set-face-attribute
       'pro-buffer-banner-face nil
       :foreground default-bg
       :background default-fg
       :weight 'bold
       :extend t
       :height pro-buffer-banner-font-scale))
    ;; The face symbol is used by `pro-buffer-banner--populate' via
    ;; `propertize'; updating the face definition refreshes all text
    ;; in the banner buffer automatically.  Force a redraw so the new
    ;; colors are visible immediately.  The `boundp' guards make this
    ;; callable before the Internal state section is loaded (e.g. from
    ;; the top-level call right after the function is defined).
    (when (and (boundp 'pro-buffer-banner--bufname)
               (stringp pro-buffer-banner--bufname)
               (get-buffer pro-buffer-banner--bufname))
      (with-current-buffer (get-buffer pro-buffer-banner--bufname)
        (force-mode-line-update t)))
    (when (and (boundp 'pro-buffer-banner--frame)
               (frame-live-p pro-buffer-banner--frame))
      (force-mode-line-update t))))

;; Apply on first load so the banner is theme-aware from the start.
(pro-buffer-banner--apply-theme-face)

;; Re-apply on every theme change.  `enable-theme-functions' is the
;; Emacs 29+ hook; we also advise `load-theme'/`disable-theme' for
;; older Emacsen and for the case where themes are toggled
;; programmatically outside of `enable-theme-functions'.
(when (boundp 'enable-theme-functions)
  (add-hook 'enable-theme-functions #'pro-buffer-banner--apply-theme-face)
  (add-hook 'disable-theme-functions #'pro-buffer-banner--apply-theme-face))
(advice-add 'load-theme :after #'pro-buffer-banner--apply-theme-face)
(advice-add 'disable-theme :after #'pro-buffer-banner--apply-theme-face)

;; ---------------------------------------------------------------------------
;; Internal state
;; ---------------------------------------------------------------------------

(defun pro-buffer-banner--timer-pending-p (timer)
  "Return non-nil if TIMER is currently scheduled (pending).
Portable replacement for the removed `timer-pending-p' (gone in Emacs 30).
A timer is pending iff it is a `timerp' object AND is present in
`timer-list' (the global list of scheduled timers). A timer that has
already fired, was cancelled, or is otherwise inactive is not pending."
  (and (timerp timer) (memq timer timer-list)))

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

(defun pro-buffer-banner--truncate (s max)
  "Truncate S to at most MAX chars. If shortened, append \"...\"."
  (if (and (stringp s) (> (length s) max))
      (concat (substring s 0 (max 0 (- max 3))) "...")
    s))

(defun pro-buffer-banner--compose-text (buffer)
  "Compose the banner text for BUFFER. Truncates with \"…\" if longer
than `pro-buffer-banner-max-text-chars'."
  (let* ((bname (buffer-name buffer))
         (proj  (pro-buffer-banner--project-name))
         (branch (and pro-buffer-banner-show-branch
                      (pro-buffer-banner--branch)))
         (max (if (and (integerp pro-buffer-banner-max-text-chars)
                       (> pro-buffer-banner-max-text-chars 0))
                  pro-buffer-banner-max-text-chars
                most-positive-fixnum))
         (parts (delq nil
                      (list (pro-buffer-banner--truncate bname max)
                            (and proj (pro-buffer-banner--truncate (format "[%s]" proj) max))
                            (and branch (pro-buffer-banner--truncate (format "(%s)" branch) max))))))
    (pro-buffer-banner--truncate (string-join parts "  ") max)))

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
  "Return a plist with :x :y :w-chars :h-chars :pixel-w :pixel-h :font.
The :pixel-w and :pixel-h are exact pixel sizes for the banner frame so
the underlying child frame has no slack around the rendered text."
  (let* ((parent (selected-frame))
         ;; Position in pixels
         (left 0) (top 0) (right 0) (bottom 0))
    (when (fboundp 'window-pixel-edges)
      (let ((edges (window-pixel-edges win)))
        (setq left   (or (nth 0 edges) 0)
              top    (or (nth 1 edges) 0)
              right  (or (nth 2 edges) left)
              bottom (or (nth 3 edges) top))))
    ;; Build a scaled font for the banner first; the banner frame's
    ;; char-width depends on this font, so we need it before sizing.
    (let* ((font (pro-buffer-banner--scaled-font parent))
           ;; Measure scaled font in pixels. We don't yet have a live
           ;; banner frame, but `font-get' on a font-spec gives us the
           ;; point size; the actual pixel width comes from the
           ;; font-driver. Approximate via the parent char-width scaled
           ;; by `pro-buffer-banner-font-scale' — this is good enough
           ;; because the scaled font has the same family/metrics as
           ;; the parent's default face.
           (scaled-char-w (max 1 (round (* pro-buffer-banner-font-scale
                                           (frame-char-width parent)))))
           (scaled-char-h (max 1 (round (* pro-buffer-banner-font-scale
                                           (frame-char-height parent)))))
           (text-len (length text))
           (pad-l (max 0 pro-buffer-banner-pad-chars))
           (pad-r (max 0 pro-buffer-banner-right-pad-chars))
           (w-chars (+ text-len pad-l pad-r))
           (h-chars 1)
           ;; Pixel size of the banner frame: exact text + padding.
           (frame-pixel-w (* w-chars scaled-char-w))
           (frame-pixel-h (* h-chars scaled-char-h))
           (parent-pixel-w (max 1 (- right left)))
           ;; Center the TEXT (not the whole frame) horizontally in the
           ;; parent window. With asymmetric padding, the right side has
           ;; more slack so the banner covers mode-line indicators on
           ;; the right while the text stays centered.
           (text-pixel-w (* text-len scaled-char-w))
           (x-raw (+ left (max 0 (/ (- parent-pixel-w text-pixel-w) 2))))
           (x (min x-raw (max left (- right frame-pixel-w))))
           ;; Margin: 0 → "one line height" of the parent's default font.
           ;; For :bottom we add a full char-height on top of the
           ;; user-configured margin so the banner clears the mode-line
           ;; (the mode-line lives in the last char-height of the window,
           ;; and a floating banner drawn over it would otherwise overlap
           ;; the cursor/percent indicators rendered on the right).
           (margin (if (> pro-buffer-banner-margin 0)
                       pro-buffer-banner-margin
                     (frame-char-height parent)))
           (bottom-clearance (+ margin (frame-char-height parent)))
           ;; Pick y based on `pro-buffer-banner-position'.
           (y-raw (if (eq pro-buffer-banner-position :bottom)
                      (- bottom frame-pixel-h bottom-clearance)
                    (+ top margin)))
           (y (max top (min y-raw (- bottom frame-pixel-h)))))
      (list :x (round x) :y (round y)
            :w-chars w-chars :h-chars h-chars
            :pixel-w frame-pixel-w
            :pixel-h frame-pixel-h
            :parent parent
            :font font))))

(defun pro-buffer-banner--scaled-font (&optional frame)
  "Return a font-spec for FRAME (default `selected-frame') scaled by
`pro-buffer-banner-font-scale'. This is what we set as the banner frame's
`font' so that `width' in chars matches the rendered text width."
  (let* ((parent-font (face-attribute 'default :font frame))
         (parent-pt-size
          (cond
           ((and parent-font (fontp parent-font))
            (font-get parent-font :size))
           ((and (stringp parent-font)
                 (string-match "[0-9.]+" parent-font))
            (string-to-number (match-string 0 parent-font)))
           (t 10.0)))
         (new-pt-size (* pro-buffer-banner-font-scale parent-pt-size)))
    (font-spec :size new-pt-size
               :weight 'normal
               :slant 'normal)))

(defun pro-buffer-banner--frame-params (geom)
  "Build a minimal, popup-only frame parameter alist for the banner frame."
  (let ((parent (plist-get geom :parent))
        (x (plist-get geom :x))
        (y (plist-get geom :y))
        (w (plist-get geom :w-chars))
        (h (plist-get geom :h-chars))
        (pixel-w (plist-get geom :pixel-w))
        (pixel-h (plist-get geom :pixel-h))
        (font (plist-get geom :font)))
    `((parent-frame . ,parent)
      (left . ,x)
      (top . ,y)
      ;; Use the scaled font so char width matches the rendered text.
      (font . ,font)
      ;; width/height in CHARACTERS of the frame's font, plus an
      ;; explicit pixel override. The char values are required for
      ;; `make-frame' to compute initial size, but the `pixel-w' /
      ;; `pixel-h' are reapplied immediately afterwards so the
      ;; underlying X11 window matches the rendered text exactly.
      (width . ,w)
      (height . ,h)
      (min-width . 1)
      (min-height . 1)
      (user-size . t)
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
    ;; Frame-local parameters only. Do NOT use `tab-bar-mode 0' etc.
    ;; (those are global toggles). Do NOT `setq' `tab-bar-format' or
    ;; `tool-bar-format' globally — those are global defvar variables
    ;; and setting them via `setq' would clobber them for the main
    ;; frame too.  We instead set them as frame parameters, which Emacs
    ;; respects on a per-frame basis.
    (set-frame-parameter frame 'line-spacing 0)
    (set-frame-parameter frame 'default-line-spacing 0)
    (set-frame-parameter frame 'tab-bar-lines 0)
    (set-frame-parameter frame 'tool-bar-lines 0)
    (set-frame-parameter frame 'menu-bar-lines 0)
    (set-frame-parameter frame 'tab-bar-format nil)
    (set-frame-parameter frame 'tool-bar-format nil)
    (set-frame-parameter frame 'name "")
    (set-frame-parameter frame 'title "")
    (set-frame-parameter frame 'icon-name "")
    (with-selected-frame frame
      (setq mode-line-format nil
            header-line-format nil
            tab-line-format nil)
      (when (boundp 'window-divider)
        (setq window-divider nil
              window-divider-width 0
              right-divider-width 0
              left-divider-width 0)))))

;; ---------------------------------------------------------------------------
;; Single persistent frame
;; ---------------------------------------------------------------------------

(defun pro-buffer-banner--ensure-frame (params width-chars)
  "Return the banner frame, creating it with PARAMS only if it doesn't exist.
After creation, explicitly resize the frame and window to be exactly
WIDTH-CHARS wide and 1 char tall — passing (width . N) (height . 1) to
`make-frame' is unreliable on some toolkits."
  (if (frame-live-p pro-buffer-banner--frame)
      pro-buffer-banner--frame
    (condition-case err
        (let* ((f (make-frame params))
               (win (frame-selected-window f)))
          (pro-buffer-banner--strip-decoration f)
          ;; Lock the window: it must not grow to fit buffer content.
          (set-window-parameter win 'window-size-fixed t)
          (when (fboundp 'window-no-other-windows)
            (set-window-parameter win 'no-other-windows t))
          ;; Force the exact pixel size. `set-frame-size' takes CHAR-HEIGHT
          ;; units only on some platforms, so we also set min-* to clamp.
          (set-frame-parameter f 'min-width 1)
          (set-frame-parameter f 'min-height 1)
          (set-frame-parameter f 'width  width-chars)
          (set-frame-parameter f 'height 1)
          (condition-case _ (set-frame-size f width-chars 1) (error nil))
          ;; Hide it after creation; we'll show explicitly on each switch.
          (set-frame-parameter f 'visibility nil)
          (setq pro-buffer-banner--frame f)
          f)
      (error
       (message "[pro-buffer-banner] frame create failed: %S" err)
       nil))))

(defun pro-buffer-banner--hide ()
  "Hide the banner frame (without deleting it) and cancel any fade.

Returns focus to the parent frame first — `override-redirect' child
frames are *not* managed by the WM, but some WMs (Xfwm, awesome, i3)
still pass focus to them on unmap. `redirect-frame-focus' + `x-focus-frame'
make the focus move deterministic regardless of WM behaviour."
  (when (and pro-buffer-banner--timer (timerp pro-buffer-banner--timer))
    (cancel-timer pro-buffer-banner--timer))
  (setq pro-buffer-banner--timer nil)
  (when (frame-live-p pro-buffer-banner--frame)
    (set-frame-parameter pro-buffer-banner--frame 'visibility nil)
    ;; Return focus to the parent frame so the banner never *holds* it
    ;; after fade-out. `redirect-frame-focus' is the canonical way
    ;; (X11/Emacs 28+); `x-focus-frame' is a belt-and-suspenders fallback
    ;; for WMs that ignore redirect.
    (ignore-errors (redirect-frame-focus pro-buffer-banner--frame
                                         (selected-frame)))
    (ignore-errors (x-focus-frame (selected-frame)))))

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

(defun pro-buffer-banner--populate (text width-chars &optional pad-l pad-r)
  "Replace current-buffer contents with TEXT padded to WIDTH-CHARS and styled.
PAD-L spaces go on the left, PAD-R on the right. If PAD-L/PAD-R are
nil, the total padding is split evenly."
  (let ((inhibit-read-only t)
        (inhibit-modification-hooks t)
        (total-pad (max 0 (- width-chars (length text))))
        (left-pad (or pad-l (/ total-pad 2)))
        (right-pad (or pad-r (- total-pad (or pad-l (/ total-pad 2))))))
    (erase-buffer)
    (when (> left-pad 0)
      (insert (propertize (make-string left-pad ?\s) 'face 'pro-buffer-banner-face)))
    (insert (propertize text 'face 'pro-buffer-banner-face))
    (when (> right-pad 0)
      (insert (propertize (make-string right-pad ?\s) 'face 'pro-buffer-banner-face)))
    (setq-local cursor-type nil)
    (setq-local window-size-fixed t)
    (setq-local mode-line-format nil)
    (setq-local header-line-format nil)
    (setq-local tab-line-format nil)
    (setq-local line-spacing 0)
    ;; Prevent wrapping/truncation ambiguity: lines past width are simply
    ;; not visible (but the frame is sized to fit, so this shouldn't trigger).
    (setq-local truncate-lines t)
    (setq-local word-wrap nil)))

;; ---------------------------------------------------------------------------
;; Fade animation
;; ---------------------------------------------------------------------------

(defun pro-buffer-banner--restart-fade ()
  "Cancel any in-flight fade, reset alpha to full, and start a fresh fade.

NOTE: kept for compatibility but **no longer called by `--show'** —
re-starting the fade on every display caused the banner to never
hide on rapid buffer switching (each new show cancelled the running
timer and started over). See `pro-buffer-banner--show' for the new
\"start only if no fade is running\" logic."
  (when (and pro-buffer-banner--timer (timerp pro-buffer-banner--timer))
    (cancel-timer pro-buffer-banner--timer))
  (setq pro-buffer-banner--timer nil)
  (when (frame-live-p pro-buffer-banner--frame)
    (set-frame-parameter pro-buffer-banner--frame 'alpha
                         pro-buffer-banner-initial-alpha))
  (pro-buffer-banner--start-fade))

(defun pro-buffer-banner--start-fade ()
  "Start the alpha fade-out for the current banner frame.
The total visible time is exactly `pro-buffer-banner-duration' seconds,
divided into `pro-buffer-banner-fade-steps' steps."
  (when (and pro-buffer-banner--timer (timerp pro-buffer-banner--timer))
    (cancel-timer pro-buffer-banner--timer))
  (setq pro-buffer-banner--timer nil)
  (let* ((frame pro-buffer-banner--frame)
         (steps (max 1 pro-buffer-banner-fade-steps))
         (initial pro-buffer-banner-initial-alpha)
         (step 0)
         ;; Total visible time = duration seconds, split into `steps' ticks.
         (step-ms (max 16 (round (* 1000.0 pro-buffer-banner-duration)
                                (float steps)))))
    (when (frame-live-p frame)
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
                 (setq step (1+ step))))))))))

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
               (frame (pro-buffer-banner--ensure-frame params width-chars)))
           (when frame
             ;; 1. Update text in-place (no recreation).
             (let ((b (get-buffer-create bufname)))
               (with-current-buffer b
                 (pro-buffer-banner--populate text width-chars
                                             pro-buffer-banner-pad-chars
                                             pro-buffer-banner-right-pad-chars))
              ;; 2. Attach buffer to the banner window if needed.
              (unless (eq (window-buffer (frame-selected-window frame)) b)
                (save-selected-window
                  (select-frame frame)
                  (set-window-buffer (selected-window) b))))
            ;; 3. Force exact geometry on the window: 1 line, no growth.
            (let ((win (frame-selected-window frame)))
              (set-window-parameter win 'window-size-fixed t))
            (set-frame-parameter frame 'left (plist-get geom :x))
            (set-frame-parameter frame 'top  (plist-get geom :y))
            (set-frame-parameter frame 'min-width 1)
            (set-frame-parameter frame 'min-height 1)
            ;; Force exact pixel size matching the rendered text. We
            ;; set `width'/`height' (in chars) ONLY as a hint for the
            ;; initial frame creation, then immediately override with
            ;; pixel-precise values. The pixel size keeps the child
            ;; frame flush with the text, so no light "halo" of empty
            ;; pixels around the banner.
            (let ((pixel-w (plist-get geom :pixel-w))
                  (pixel-h (plist-get geom :pixel-h)))
              (set-frame-parameter frame 'user-size t)
              (condition-case _ (set-frame-size frame pixel-w pixel-h :pixels) (error nil)))
            ;; 4. Re-apply decoration stripping on every show: the
            ;; `set-frame-size'/parameter calls above can otherwise let
            ;; the tab/tool/menu bars grow back if the global
            ;; `tab-bar-mode' is enabled (it is, via pro-tabs). Doing
            ;; this here keeps the banner a pure text label even after
            ;; repeated buffer switches.
            (pro-buffer-banner--strip-decoration frame)
            ;; 5. Show. We do NOT restart the fade on every show —
            ;; that would cause the banner to *never* hide on rapid
            ;; buffer switching (each new show cancelled the running
            ;; timer and started over). Instead, start a fresh fade
            ;; only if no fade is currently running. Result: the
            ;; visible time is always `pro-buffer-banner-duration'
            ;; from the *first* display in a burst, then the banner
            ;; auto-hides regardless of how many more switches happen.
            (set-frame-parameter frame 'visibility t)
            ;; Keep focus on the parent frame. `no-focus-on-map' in
            ;; `pro-buffer-banner--frame-params' is not enough on every
            ;; WM; explicitly redirect focus back to the selected
            ;; frame after the map. (X11/Emacs 28+ for redirect-frame-focus.)
            (ignore-errors (redirect-frame-focus frame (selected-frame)))
            (ignore-errors (x-focus-frame (selected-frame)))
            (unless (and pro-buffer-banner--timer
                         (timerp pro-buffer-banner--timer)
                         (pro-buffer-banner--timer-pending-p
                          pro-buffer-banner--timer))
              ;; No running fade: start one. Reset alpha to full so a
              ;; mid-fade re-display doesn't show a half-transparent
              ;; banner.
              (set-frame-parameter frame 'alpha
                                   pro-buffer-banner-initial-alpha)
              (pro-buffer-banner--start-fade))
            (setq pro-buffer-banner--last-shown-at (float-time))))
      (error
       (message "[pro-buffer-banner] show failed: %S" err)
       (pro-buffer-banner--destroy)))))

(defun pro-buffer-banner--maybe-show (&optional _frame)
  "Watcher invoked from `post-command-hook' / `window-selection-change-functions'.
Show the banner on buffer/window change.  _FRAME is ignored — it is passed by
`window-selection-change-functions' but the function determines the target
window dynamically via `selected-window'."
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
    (add-hook 'post-command-hook #'pro-buffer-banner--maybe-show 90))
  ;; Emacs 27+: also listen to `window-selection-change-functions' so
  ;; the banner is (re-)shown whenever the selected window changes,
  ;; independently of `post-command-hook' firing.  This is the
  ;; canonical signal for window switches and is more reliable than
  ;; post-command-hook (which can be delayed or skipped in some edge
  ;; cases — e.g. when a window switch is triggered by something other
  ;; than an interactive command, or when commands fail before the
  ;; hook fires).  The watcher is idempotent via its own change
  ;; detection, so firing from both hooks is safe.
  (when (boundp 'window-selection-change-functions)
    (unless (memq #'pro-buffer-banner--maybe-show window-selection-change-functions)
      (add-hook 'window-selection-change-functions #'pro-buffer-banner--maybe-show))))

(defun pro-buffer-banner--uninstall ()
  "Uninstall the watcher hook and tear down any visible banner."
  (remove-hook 'post-command-hook #'pro-buffer-banner--maybe-show)
  (when (boundp 'window-selection-change-functions)
    (remove-hook 'window-selection-change-functions #'pro-buffer-banner--maybe-show))
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

;; ---------------------------------------------------------------------------
;; Soft reload integration
;; ---------------------------------------------------------------------------
;; The banner frame is created ONCE and reused on every show. After a
;; `pro/reload-config' the .el file is re-evaluated, but the existing
;; frame keeps its old geometry (width/height/font) because those were
;; baked in at creation time. Hook the after-reload teardown so the
;; next show rebuilds the frame from the freshly loaded code.

(defun pro-buffer-banner--reload-reset ()
  "Teardown function for `pro--after-reload-hook'.
Destroys the persistent banner frame and the backing buffer so the
next `pro-buffer-banner--show' recreates them using the freshly
loaded module's parameters (font scale, width calc, decoration
stripping, etc.)."
  (when (fboundp 'pro-buffer-banner--destroy)
    (ignore-errors (pro-buffer-banner--destroy)))
  ;; Backing buffer keeps the same name across reloads; kill it so the
  ;; next show gets a clean slate.
  (when (and (boundp 'pro-buffer-banner--bufname)
             pro-buffer-banner--bufname
             (get-buffer pro-buffer-banner--bufname))
    (ignore-errors (kill-buffer pro-buffer-banner--bufname)))
  (setq pro-buffer-banner--bufname nil
        pro-buffer-banner--last-buf nil
        pro-buffer-banner--last-win nil
        pro-buffer-banner--last-shown-at 0.0)
  ;; Re-apply the theme-aware face in case the user changed
  ;; `pro-buffer-banner-font-scale' or the theme color in the
  ;; reloaded code.  This must run after the frame is destroyed and
  ;; before the next show.
  (when (fboundp 'pro-buffer-banner--apply-theme-face)
    (ignore-errors (pro-buffer-banner--apply-theme-face))))

(ignore-errors
  (when (fboundp 'pro/after-reload)
    (pro/after-reload #'pro-buffer-banner--reload-reset)))

(provide 'pro-buffer-banner)

;;; pro-buffer-banner.el ends here
