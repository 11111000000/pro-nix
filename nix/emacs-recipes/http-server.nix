{ stdenv, emacs, fetchFromCodeberg, lib }:

stdenv.mkDerivation rec {
  pname = "http-server";
  version = "unstable-2026-06-09";

  src = fetchFromCodeberg {
    owner = "martenlienen";
    repo = "http-server.el";
    rev = "4285bd3e4b67983cb783f46afc736032f895882d";
    sha256 = "sha256-iII8JAt+unfn25ypzKyMA/iMhmqqW7wr0/n1rcg8m3M=";
  };

  nativeBuildInputs = [ emacs ];
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/share/emacs/site-lisp/${pname}
    cp ./*.el $out/share/emacs/site-lisp/${pname}/
  '';
  meta = with lib; {
    description = "Speaks HTTP for you — minimal HTTP/1.1 + WebSocket server for Emacs";
    homepage = "https://codeberg.org/martenlienen/http-server.el";
    license = licenses.gpl3Plus;
    platforms = platforms.unix;
  };
}
