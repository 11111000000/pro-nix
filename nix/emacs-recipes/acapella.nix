{ stdenv, emacs, lib }:

stdenv.mkDerivation rec {
  pname = "acapella";
  version = "0.0.0";
  src = ../../submodules/acapella;

  nativeBuildInputs = [ emacs ];
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    emacs --batch -Q -L lisp -f batch-byte-compile lisp/*.el 2>/dev/null || true
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/emacs/site-lisp/${pname}
    cp -r lisp/*.el $out/share/emacs/site-lisp/${pname}/
    cp -r lisp/*.elc $out/share/emacs/site-lisp/${pname}/ 2>/dev/null || true
    runHook postInstall
  '';

  meta = with lib; {
    description = "Acapella Emacs package (gnu-emacs-ru/acapella)";
    homepage = "https://github.com/gnu-emacs-ru/acapella";
    license = licenses.mit;
  };
}