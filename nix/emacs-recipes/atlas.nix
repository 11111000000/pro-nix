{ stdenv, emacs, lib, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "atlas";
  version = "0.0.0";
  src = fetchFromGitHub {
    owner = "gnu-emacs-ru";
    repo = "atlas";
    rev = "0aed422c57ed964b5fa7a2f988bb64b1bde924eb";
    sha256 = "sha256-4fJ++QR6e/LSBYH3RokJq+nEqtGRJx5zmeUrroIxOjo=";
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
    description = "Atlas Emacs package (gnu-emacs-ru/atlas)";
    homepage = "https://github.com/gnu-emacs-ru/atlas";
    license = licenses.mit;
  };
}