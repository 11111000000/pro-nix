{ stdenv, emacs, lib, gptel ? null }:

stdenv.mkDerivation rec {
  pname = "carriage";
  version = "dev";
  src = builtins.fetchTree { type = "github"; owner = "gnu-emacs-ru"; repo = "carriage"; rev = "4c18e9bfe4a195ae305f814c68eae02383e33842"; narHash = "sha256-DJ0cbAhHbcJcdIN2cYueq0P1lgRDkclQNDr6RNp/728="; };

  nativeBuildInputs = [ emacs ];
  buildInputs = if gptel != null then [ gptel ] else [ ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    GP_FLAGS=""
    if ls ${if gptel != null then gptel else "\"\""}/share/emacs/site-lisp/elpa/gptel-*/gptel.el 2>/dev/null; then
      GP_FLAGS="-L $(ls -d ${if gptel != null then gptel else "\"\""}/share/emacs/site-lisp/elpa/gptel-* | head -1)"
    fi
    for dir in lisp carriage; do
      if [ -d "$dir" ]; then
        cd "$dir"
        emacs --batch -Q $GP_FLAGS -L . -f batch-byte-compile *.el 2>/dev/null || true
        cd ..
      fi
    done
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/emacs/site-lisp/${pname}
    for dir in lisp carriage; do
      if [ -d "$dir" ]; then
        cp "$dir"/*.el  $out/share/emacs/site-lisp/${pname}/ 2>/dev/null || true
        cp "$dir"/*.elc $out/share/emacs/site-lisp/${pname}/ 2>/dev/null || true
      fi
    done
    echo "=== carriage installed: $(ls $out/share/emacs/site-lisp/${pname}/ | wc -l) files ==="
    runHook postInstall
  '';

  meta = with lib; {
    description = "Code knitting machine for Emacs/Org (gnu-emacs-ru/carriage)";
    homepage = "https://github.com/gnu-emacs-ru/carriage";
    license = licenses.lgpl2Only;
  };
}