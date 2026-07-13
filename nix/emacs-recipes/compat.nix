{ stdenv, emacs, lib, fetchFromGitHub }:

# compat (emacs-compat/compat) — backwards-compatibility polyfill для Emacs Lisp.
# Nixpkgs-рецепт `emacsPackages.compat` (на 2026-07) запинен на tag
# `30.1.0.1` (Jun 2025), а `transient-0.13.5` требует `compat >= 31.0`.
# Без этого патча `transient.el` не байт-компилируется:
#   transient.el:52:11: Error: Cannot open load file: No such file or
#   directory, cond-let
# (на самом деле причина глубже: после compat 31.x появилась `compat-call'
# и cond-let как зависимость).
#
# Этот recipe — прямой `mkDerivation` поверх официального тега 31.0.0.2,
# без elpa2nix.
#
# Pin: tag 31.0.0.2 (commit df03e91…, 2026-07-09).
# License: GPL-3.0.

stdenv.mkDerivation rec {
  pname = "compat";
  version = "31.0.0.2";

  src = fetchFromGitHub {
    owner = "emacs-compat";
    repo = "compat";
    rev = "${version}";  # теги emacs-compat/compat без префикса 'v'
    hash = "sha256-ptmRg0+ZODG+CeOjaF5jzMmHVrDKujyFiqYW3vWKjS0=";
  };

  nativeBuildInputs = [ emacs ];

  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/emacs/site-lisp/${pname}
    for f in compat.el compat-*.el; do
      [ -f "$f" ] && install -m644 "$f" $out/share/emacs/site-lisp/${pname}/
    done
    runHook postInstall
  '';

  meta = with lib; {
    description = "compat — backwards-compatibility polyfill for Emacs Lisp";
    homepage = "https://github.com/emacs-compat/compat";
    license = with licenses; [ gpl3Plus ];
    platforms = platforms.unix;
  };
}