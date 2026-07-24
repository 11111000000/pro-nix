{ stdenv, emacs, lib }:

stdenv.mkDerivation rec {
  pname = "shaoline";
  version = "3.3.7";
  src = ../../submodules/shaoline;

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
