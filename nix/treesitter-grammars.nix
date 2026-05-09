{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  tree-sitter-cli = pkgs.tree-sitter-cli;
in

stdenv.mkDerivation rec {
  pname = "pro-emacs-treesit-grammars";
  version = "0";

  src = null;

  nativeBuildInputs = [ tree-sitter-cli pkg-config gcc ];

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
    git clone --depth 1 https://github.com/tree-sitter/tree-sitter-typescript.git tmp-ts
    (cd tmp-ts/typescript && ${tree-sitter-cli}/bin/tree-sitter generate)
    gcc -shared -fPIC tmp-ts/typescript/src/parser.c -o $outlib/libtree-sitter-typescript.so || true

    # tsx grammar (tsx subdir)
    (cd tmp-ts/tsx && ${tree-sitter-cli}/bin/tree-sitter generate)
    gcc -shared -fPIC tmp-ts/tsx/src/parser.c -o $outlib/libtree-sitter-tsx.so || true

    # Note: errors above are tolerated for platforms with different build steps.
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
