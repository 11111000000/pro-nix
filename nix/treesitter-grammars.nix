{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  # Prefer using precompiled grammars bundle from emacs-tree-sitter/tree-sitter-langs
  # which provides prebuilt .so files for many languages on x86_64 Linux.
  tsBundle = fetchurl {
    url = "https://github.com/emacs-tree-sitter/tree-sitter-langs/releases/download/0.13.49/tree-sitter-grammars.x86_64-unknown-linux-gnu.v0.13.49.tar.gz";
    # sha256 for the bundle observed during a local build
    sha256 = "HCxf8X/HJpTZpT7aQOqNscC9waiaVUr7RJannlExngA=";
  };

in

stdenv.mkDerivation rec {
  pname = "pro-emacs-treesit-grammars";
  version = "0";

  src = tsBundle;

  nativeBuildInputs = [ pkg-config gcc git ];

  buildInputs = [ libtool ];

  unpackPhase = ''
    mkdir -p $TMPDIR/grammars
    cd $TMPDIR/grammars
  '';

  buildPhase = ''
    set -e
    outlib=$out/lib
    mkdir -p $outlib

    # Unpack the prebuilt grammars bundle and copy libraries for requested languages.
    tmpdir=$(mktemp -d)
    tar xzf "${tsBundle}" -C "$tmpdir"

    # Copy any available libtree-sitter-*.so into $out/lib
    find "$tmpdir" -type f -name 'libtree-sitter-*.so' -exec cp {} "$outlib" \; || true

    echo "Copied tree-sitter .so files to $outlib"
  '';

  installPhase = ''
    mkdir -p $out/lib
    echo "Installed grammars to $out/lib"
  '';

  meta = with lib; {
    description = "Builder for tree-sitter grammars used by Emacs (typescript/tsx)";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
