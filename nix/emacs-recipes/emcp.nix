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
  meta = with lib; {
    description = "EMCP — MCP server that lets an LLM agent talk to Emacs";
    homepage = "https://codeberg.org/martenlienen/emcp";
    license = with licenses; [ gpl3Plus ];
    platforms = platforms.unix;
  };
}
