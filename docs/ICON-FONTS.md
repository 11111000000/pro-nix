Icon fonts
==========

pro-nix UI optionally uses patched icon fonts (Nerd Fonts / all-the-icons)
to display icons in completion lists, dired and ibuffer. If icons are not
installed the UI falls back to text. This document gives short guidance.

Recommended families (install one of these):

- FiraCode Nerd Font
- Hack Nerd Font
- DejaVu Sans Mono Nerd Font

Linux (manual):

1. Download patched TTF from https://www.nerdfonts.com/
2. Install to ~/.local/share/fonts/ or system fonts directory.
3. fc-cache -f -v

Home‑Manager snippet (example):

fonts.packages = with pkgs; [ (pkgs.fetchzip {
  url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip";
  # sha256 example computed on 2026-05-05
  sha256 = "19izxgb3lazlvbcwzk3vnvd68x11n90qk02r05gi1nc8bz6vqgvk";
}) ]

If icons are missing, run `M-x pro-ui-check-icon-fonts` for guidance.
