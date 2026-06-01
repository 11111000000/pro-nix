{ stdenv, emacs, lib, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "acapella";
  version = "0.0.0";
  src = fetchFromGitHub {
    owner = "gnu-emacs-ru";
    repo = "acapella";
    rev = "c7b9aa46c1298740fb49bbb58ca5ad902d7e4522";
    sha256 = "sha256-USeW75QnYQ04REt9Fauvh+nx830vpiDPae1Vi9+o5sI=";
  };

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