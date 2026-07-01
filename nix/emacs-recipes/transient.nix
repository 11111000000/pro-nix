{ stdenv, emacs, lib, fetchurl }:

# transient — keyboard-driven modal menus library used by Magit.
#
# Source: GNU ELPA tarball `transient-0.13.4.tar` (2026-Jun-01).
# Why a custom recipe: nixpkgs 25.11 ships `emacs-transient-20251006.1815`,
# which corresponds to transient 0.10.1. Magit requires `transient >= 0.13`,
# so the upstream nixpkgs version is too old and Magit aborts startup with:
#   "Emergency (magit): Magit requires 'transient' >= 0.13"
# Pin to the latest 0.13.x release on GNU ELPA. Newer versions should bump
# the version + hash below; ELPA releases are stable so this is low-risk.
#
# License: GPL-3.0-or-later.
#
# Runtime deps (Package-Requires in transient.el): compat >= 30.1,
# cond-let, seq. We walk each dep's `share/emacs/site-lisp/` recursively
# and add every subdirectory that contains .el files to the load path
# — mirrors the pattern from ellama.nix / carriage.nix. This is needed
# because nixpkgs puts each ELPA package under
#   `share/emacs/site-lisp/elpa/<pname>-<version>/`
# rather than a flat `share/emacs/site-lisp/<pname>/`, so a hard-coded
# `-L` path wouldn't match.

stdenv.mkDerivation rec {
  pname = "transient";
  version = "0.13.4";

  src = fetchurl {
    url = "https://elpa.gnu.org/packages/transient-${version}.tar";
    sha256 = "sha256-0OCfQCFH1RKx9DY/tbSJL2mDD5HY0AU18wuU3VkXJAg=";
  };

  nativeBuildInputs = [ emacs ];

  compat = emacs.pkgs.compat;
  cond-let = emacs.pkgs.cond-let;
  seq = emacs.pkgs.seq;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    LP_ARGS=""
    for PKG_ROOT in \
      ${compat}/share/emacs \
      ${cond-let}/share/emacs \
      ${seq}/share/emacs; do
      if [ -d "$PKG_ROOT" ]; then
        for SUBDIR in $(find "$PKG_ROOT" -type d); do
          [ -n "$(ls "$SUBDIR"/*.el 2>/dev/null)" ] && LP_ARGS="$LP_ARGS -L $SUBDIR"
        done
      fi
    done
    ${emacs}/bin/emacs --batch -Q -L . $LP_ARGS -f batch-byte-compile *.el
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/emacs/site-lisp/${pname}
    install -m644 *.el *.elc $out/share/emacs/site-lisp/${pname}/
    runHook postInstall
  '';

  meta = with lib; {
    description = "transient — keyboard-driven command menus (Magit/Forge/etc.)";
    homepage = "https://github.com/magit/transient";
    license = with licenses; [ gpl3Plus ];
    platforms = platforms.unix;
  };
}