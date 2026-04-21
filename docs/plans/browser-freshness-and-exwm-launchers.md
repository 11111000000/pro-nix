<!-- Русский: комментарии и пояснения оформлены в стиле учебника -->
# Browser freshness and EXWM launchers

## Goal
Keep Firefox current by tracking `nixpkgs` updates, and make Chromium and Google Chrome appear as explicit desktop launchers inside EXWM.

## Findings
- Current package names in `nixpkgs` are `chromium`, `google-chrome`, `firefox`, `firefox-bin`, and `firefox-esr`.
- The config already uses `programs.firefox.package = pkgs.firefox`, so Firefox freshness is tied to `nixpkgs` freshness.
- `system-packages.nix` currently wraps `chromium` and `firefox`, but does not provide `google-chrome`.
- EXWM needs desktop entries or a launcher that reads XDG applications; PATH entries alone are not enough.

## Plan
1. Keep Firefox on `pkgs.firefox` and document that a `nix flake update` plus rebuild is the freshness mechanism.
2. Add `google-chrome` to the browser wrappers so both Chromium and Chrome are available from the shell.
3. Create explicit `.desktop` launchers for Firefox, Chromium, and Google Chrome under `~/.local/share/applications` so EXWM can show them in its application menu.
4. Verify the launcher names and package names match current `nixpkgs`.

## Risks
- If the EXWM launcher does not read XDG desktop files, the entries will still exist but may not show automatically.
- `google-chrome` remains unfree; the existing `allowUnfree = true` config already covers that.
