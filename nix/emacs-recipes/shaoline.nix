{ stdenv, emacs, lib }:

stdenv.mkDerivation rec {
  pname = "shaoline";
  version = "3.3.4";
  src = builtins.fetchTree {
    type = "github";
    owner = "11111000000";
    repo = "shaoline";
    rev = "e4fa70ddd910b8517104093473aa19f8a37f9bc1";
    narHash = "sha256-zBiLqfUccQbkRTjrg789An3KGFosxIkUY5H6AMUY57I=";
  };

  nativeBuildInputs = [ emacs ];
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    # Compile Elisp files located in lisp/
    emacs --batch -Q -L lisp -f batch-byte-compile lisp/*.el 2>/dev/null || true
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/emacs/site-lisp/${pname}
    cp lisp/*.el $out/share/emacs/site-lisp/${pname}/
    cp lisp/*.elc $out/share/emacs/site-lisp/${pname}/ 2>/dev/null || true
    runHook postInstall
  '';

  meta = with lib; {
    description = "shaoline modeline (11111000000/shaoline)";
    homepage = "https://github.com/11111000000/shaoline";
    license = licenses.mit;
  };
}
