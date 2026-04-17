# Plan: TTY improvements

## Goal
Make TTY more comfortable: better Cyrillic font, higher resolution, improved colors, better boot experience.

## Current problems
1. Font `latarcyrheb-sun16` is dated, not very legible at high resolution
2. No boot splash (Plymouth) - raw text during boot
3. VT resolution may not use native display mode
4. Alt in Emacs on TTY - limited by Linux VT itself
5. Cursor/boot verbosity/color polish is not tuned for a calm TTY feel

## Changes to make

### 1. Better console font
Replace `latarcyrheb-sun16` with Terminus console font which is sharper and has good Cyrillic.

In `configuration.nix`, section "Раздел 8: Масштабная настройка клавиатуры и ввода":

```nix
# Old:
console.font = "${pkgs.kbd}/share/consolefonts/latarcyrheb-sun16.psfu.gz";

# New:
console.font = "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";
```

Or try other Terminus variants: `ter-v14n`, `ter-v18n` depending on preferred size.

### 2. Add Plymouth for boot polish
Add boot splash with native resolution.

In `configuration.nix`, add to section "Раздел 2: Загрузчик системы и параметры ядра" or create new section:

```nix
boot.plymouth.enable = true;
boot.plymouth.theme = "bgrt";  # or "spinner" or other available theme
```

Note: Plymouth requires kernel to have KMS active early - already the case with Intel graphics and modesetting driver.

### 3. Force native resolution in TTY
The current `services.xserver.videoDrivers = [ "modesetting" ]` should already give KMS early, but can add explicit video mode.

In `boot.kernelParams`, add:

```nix
boot.kernelParams = [
  # existing params...
  "video=1920x1080"  # or let it auto-detect native resolution
];
```

Or use `video=HDMI-1:1920x1080@60` if specific connector.

### 4. Add small visual polish
These are low-risk and improve perceived quality.

Possible additions:
- `boot.kernelParams` with `quiet` and a lower `loglevel=` if boot noise is too high.
- `vt.global_cursor_default = 0` if the blinking cursor feels ugly.
- Keep Plymouth as the default boot presentation so the console does not flash raw text.

### 5. Alt handling in Emacs
Keep as-is for now since the TTY limitation is fundamental. If Emacs Alt is problematic, tune Emacs itself (e.g., set `x-alt-meta` or use Esc instead).

The `console.useXkbConfig = true` already helps consistency between X11 and TTY.

## Changes summary

| Change | Risk | Effort |
|--------|------|--------|
| Change console font | Low | 1 line |
| Enable Plymouth | Low | 2-3 lines |
| Add video= kernel param | Medium | 1 line |
| Reduce cursor/boot noise | Low | 1-2 lines |

## Excluded from this plan
- Wayland compositor instead of Xorg - that's a bigger change, separate from TTY improvements
- Replacing Linux VT with something like KMSCON - not necessary if above improvements are enough
- Switching to a Wayland session - useful later, but separate from TTY work

## Testing
After rebuild:
1. Check TTY font at boot - should be sharper
2. Check boot splash appears (if Plymouth enabled)
3. Check native resolution in VT (Ctrl+Alt+F2 etc.)
4. Test Alt combinations in Emacs on TTY
5. Check that cursor and boot text feel calmer, not louder
