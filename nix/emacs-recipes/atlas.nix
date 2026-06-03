{ stdenv, emacs, lib }:

stdenv.mkDerivation rec {
  pname = "atlas";
  version = "0.0.0";
  src = ../../submodules/atlas;

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
    description = "Atlas Emacs package (gnu-emacs-ru/atlas)";
    homepage = "https://github.com/gnu-emacs-ru/atlas";
    license = licenses.mit;
  };
}