<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# TTY improvements research

## Current state in this config
- `console.useXkbConfig = true`
- `console.earlySetup = true`
- `console.font = latarcyrheb-sun16`
- `services.xserver.xkb.options = "grp:toggle,caps:ctrl_modifier,grp_led:caps"`
- `boot.kernel.sysctl."kernel.sysrq" = 1`
- `boot.plymouth.enable = true`
- `nix.settings.substituters` now prefers `nix-community` and the Fastly mirror before `cache.nixos.org`

## What can be improved
### 1. Better Alt/Meta handling in Emacs on TTY
This is partly a TTY issue and partly an Emacs terminal issue.

Possible improvements:
- Use a terminal-friendly key mapping in Emacs so `Alt` is treated as `Meta`.
- Prefer terminal settings that pass ESC-prefixed Meta sequences cleanly.
- Check whether the current keyboard layout/options conflict with `Alt` combos.
- Keep using `console.useXkbConfig = true`, since it already helps the VT inherit XKB layout/options.

Practical note:
- In Linux VT, `Alt` is not as rich or consistent as in GUI terminals. Some combinations are intercepted by the console itself or by the kernel.
- The `Right Alt` layout switching trick works, but it can make `Alt` behavior feel less predictable in applications.

### 2. Better TTY resolution
Yes, this is usually possible.

Options:
- Force a higher framebuffer/KMS console resolution via kernel parameters.
- Keep DRM/KMS enabled so the VT uses the native display mode earlier.
- Use a larger console font that still remains readable at higher resolution.

Typical directions:
- Set a specific mode with `video=...` kernel parameters.
- Ensure the Intel graphics stack uses KMS early.
- If needed, add `drm.debug` or similar only for diagnostics.

### 3. Better Cyrillic font in TTY
Yes.

What helps:
- Choose a console font with good Cyrillic coverage and shape.
- Try multiple console fonts and sizes, not just `latarcyrheb-sun16`.
- Keep `console.earlySetup = true` so the nicer font appears early in boot.

Likely candidates to test:
- `ter-v16n.psf.gz`
- other Terminus console fonts
- other `kbd` console fonts with Cyrillic support

Important limitation:
- TTY fonts are bitmap console fonts, not full fontconfig fonts. The quality ceiling is lower than in a graphical terminal emulator.

### 4. Better colors in TTY
Partly yes, but with limits.

What is realistic:
- Better resolution and cleaner rendering via KMS/framebuffer.
- Better boot splash and less mode switching with Plymouth.
- Proper kernel-mode console colors and a cleaner palette.

What is not realistic in a normal Linux VT:
- Full modern 24-bit "graphical terminal" color quality like Kitty/WezTerm/foot.
- Smooth font rendering comparable to GUI terminals.

So the answer is:
- Yes, you can make the console look much nicer.
- No, the classic VT will still not become a true modern terminal emulator.

### 5. Boot splash and prettier early boot
Yes, if you want a more polished feel.

Use cases:
- Plymouth theme for a nicer boot splash.
- Less ugly text flicker during boot.
- Native resolution earlier.

### 6. Keyboard repeat and input feel
Already partly configured with `kbdrate`, but can be tuned further.

Possible tweaks:
- Faster key repeat for text editing.
- Better delayed repeat timing.
- Make sure console layout matches XKB layout exactly.

### 7. Locale and Unicode consistency
Already mostly good, but worth keeping aligned:
- `LANG=ru_RU.UTF-8`
- `console.useXkbConfig = true`
- a Cyrillic-friendly console font

This reduces surprises with Russian text in TTY tools.

### 8. Visual polish beyond font and resolution
These are small but noticeable.

Possible tweaks:
- Hide the blinking cursor in VT if it is distracting.
- Reduce kernel verbosity on screen with `quiet`/`loglevel=` when appropriate.
- Keep the boot path clean so Plymouth is visible instead of noisy text.
- Use a simpler boot theme and avoid flashing mode changes.

### 9. Console color palette and boot colors
The classic Linux VT is limited, but the feel can still improve.

What helps:
- KMS/framebuffer for proper native modes.
- Plymouth for controlled boot colors and transitions.
- A consistent terminal palette in X11/Wayland later, so TTY and GUI feel related.

What remains limited:
- No true GUI-style anti-aliased rendering in VT.
- No full 24-bit terminal experience in classic console.
- No font shaping/ligatures like modern terminal emulators.

## Can TTY be "graphical without Xorg"?
Yes, partially.

There are three different meanings:
1. Linux VT with KMS/framebuffer: yes, nicer resolution and colors, but still a console.
2. Plymouth: yes for boot splash, but not an interactive desktop.
3. Wayland-native terminal or compositor: yes, but that is no longer a TTY.

If the goal is "no Xorg, but nicer text display", then KMS/framebuffer + Plymouth is the realistic path.

## Recommendations for this system
- Keep `console.useXkbConfig = true`.
- Consider a sharper console font than `latarcyrheb-sun16`.
- Raise VT resolution via KMS/kernel mode setting if the current mode is low.
- Consider Plymouth for boot polish.
- If `Alt` in Emacs is the main pain point, tune Emacs terminal key handling rather than expecting the console alone to solve it.
- For caches, prefer a short connect timeout and fallback so Nix can move on quickly when a cache is slow or empty.
- Add a couple of small visual polish items if you want the VT to feel calmer rather than louder.

## Constraints
- Linux VT is still limited compared to GUI terminals.
- Font quality is constrained by console font formats.
- Color depth and rendering are limited by the console stack.

## Next step
If you want, the next pass can turn this into a concrete NixOS proposal with specific options and minimal edits to `configuration.nix`.
