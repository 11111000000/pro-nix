{ stdenv, emacs, lib, fetchgit }:

# http-server.el is not in MELPA/ELPA — it lives on Codeberg:
#   https://codeberg.org/martenlienen/http-server.el
#
# We fetch via git from Codeberg directly (no GitHub mirror exists for
# this repo).  Used by `emcp' as a propagated dependency — emcp.el
# declares `(require 'http-server)' at top level.
#
# http-server.el declares: Package-Requires: ((emacs "30.1")) and uses
# only built-in libraries (cl-lib, rx, seq, url-util), so no further
# propagated inputs are required.

stdenv.mkDerivation rec {
  pname = "http-server";
  version = "0.1.0-unstable-2026-06-09";

  src = fetchgit {
    url = "https://codeberg.org/martenlienen/http-server.el.git";
    rev = "4285bd3e4b4ee3e3d6f5bff9ea2ad0b8c2c7d31d";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ emacs ];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/emacs/site-lisp/${pname}
    cp ./*.el $out/share/emacs/site-lisp/${pname}/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Minimal HTTP server for Emacs — speaks HTTP/1.1 and WebSockets";
    longDescription = ''
      http-server is a building block for other packages that want to offer
      an HTTP server inside of Emacs to communicate with the user or external
      programs. Used by EMCP to expose the Emacs side of an MCP server.
    '';
    homepage = "https://codeberg.org/martenlienen/http-server.el";
    license = licenses.gpl3Plus;
    platforms = platforms.unix;
  };
}
