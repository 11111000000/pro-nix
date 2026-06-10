{ stdenv, emacs, lib }:

stdenv.mkDerivation rec {
  pname = "acp";
  version = "0-unstable-2026-06-11";
  src = ../../submodules/acp;

  nativeBuildInputs = [ emacs ];
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/share/emacs/site-lisp/${pname}
    cp ./*.el $out/share/emacs/site-lisp/${pname}/
  '';
  meta = with lib; {
    description = "ACP protocol client for Emacs (xenodium/acp.el fork)";
    homepage = "https://github.com/xenodium/acp.el";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
