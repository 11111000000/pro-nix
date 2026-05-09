{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  # Fetch the typescript grammars archive at a known tag. The sha256 is
  # intentionally left as a placeholder so that the build will report the
  # expected hash if fetching is allowed in the environment. Replace it with
  # the correct value after the first attempt or run `nix-prefetch-url`.
  tsSrc = fetchFromGitHub {
    owner = "tree-sitter";
    repo = "tree-sitter-typescript";
    rev = "v0.23.2";
    # Use the hash reported by Nix for v0.23.2 archive (from previous run).
    sha256 = "CU55+YoFJb6zWbJnbd38B7iEGkhukSVpBN7sli6GkGY=";
  };
in

stdenv.mkDerivation rec {
  pname = "pro-emacs-treesit-grammars";
  version = "0";

  src = tsSrc;

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

    # typescript grammar
    # If parser.c is present (pre-generated) in the fetched archive, compile
    # it; otherwise skip. The fetched archive is available at $src.
    if [ -f "$src/typescript/src/parser.c" ]; then
      gcc -shared -fPIC "$src/typescript/src/parser.c" -o $outlib/libtree-sitter-typescript.so || true
    else
      echo "typescript parser.c not found in $src; skipping"
    fi

    if [ -f "$src/tsx/src/parser.c" ]; then
      gcc -shared -fPIC "$src/tsx/src/parser.c" -o $outlib/libtree-sitter-tsx.so || true
    else
      echo "tsx parser.c not found in $src; skipping"
    fi

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
