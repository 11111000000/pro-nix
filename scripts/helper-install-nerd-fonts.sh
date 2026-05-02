#!/usr/bin/env bash
set -euo pipefail
# Simple installer for a single Nerd Font (FiraCode) into user fonts dir.
# This script is intentionally minimal and interactive; it downloads a zip
# from the Nerd Fonts repo and installs ttf files to ~/.local/share/fonts.

FONT="FiraCode"
VER="5.2.1" # adjust as needed
OUTDIR="$HOME/.local/share/fonts/nerd-fonts"
TMPDIR=$(mktemp -d)
ZIP="$TMPDIR/${FONT}.zip"

echo "Installing ${FONT} Nerd Font into ${OUTDIR}"
mkdir -p "$OUTDIR"
echo "Downloading..."
curl -L -o "$ZIP" "https://github.com/ryanoasis/nerd-fonts/releases/download/v${VER}/${FONT}.zip"
echo "Extracting..."
unzip -o "$ZIP" -d "$TMPDIR"
echo "Copying ttf files..."
find "$TMPDIR" -type f -iname '*Windows Compatible.ttf' -exec cp {} "$OUTDIR" \; || true
find "$TMPDIR" -type f -iname '*.ttf' -exec cp -n {} "$OUTDIR" \; || true
fc-cache -f
echo "Installed fonts to $OUTDIR"
echo "Run M-x pro-ui-check-icon-fonts in Emacs to verify availability."
