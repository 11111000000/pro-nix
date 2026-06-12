{ stdenv, emacs, lib }:

stdenv.mkDerivation rec {
  pname = "emcp";
  version = "0-unstable-2026-06-11";
  src = ../../submodules/emcp;

  nativeBuildInputs = [ emacs ];
  dontConfigure = true;
  # Skip the upstream Makefile: it pulls in dev tooling (test runners, mocks)
  # we don't need at install time. Site-lisp only needs the .el sources, like
  # the rest of our local-recipe packages.
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/share/emacs/site-lisp/${pname}
    cp ./*.el $out/share/emacs/site-lisp/${pname}/
  '';
  # http-server.el is a hard runtime dep — emcp.el does
  # `(require 'http-server)' at top level. Propagate so the user does
  # not have to declare it in their profile.
  # http-server is a runtime dependency of emcp (emcp.el does (require 'http-server)).
  # We do not force-provide http-server here; the NixOS / user should include
  # a suitable http-server package if they want EMCP to use the embedded HTTP
  # transport. Historically http-server lived on Codeberg and required a
  # separate recipe; to keep this flake clean we leave it optional.
  meta = with lib; {
    description = "EMCP — MCP server that lets an LLM agent talk to Emacs";
    homepage = "https://codeberg.org/martenlienen/emcp";
    license = with licenses; [ gpl3Plus ];
    platforms = platforms.unix;
  };
}
