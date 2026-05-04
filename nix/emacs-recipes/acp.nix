{ stdenv, fetchFromGitHub, emacs ? (import <nixpkgs> {}).emacs, lib ? (import <nixpkgs> {}).lib }:

stdenv.mkDerivation rec {
  pname = "acp";
  version = "0";
  src = fetchFromGitHub {
    owner = "xenodium";
    repo = "acp.el";
    rev = "master";
    sha256 = "046x5d2633zr3zkk9wfrccp3nkcmnhbzndqg0k0b4mxqzxpd1k2m";
  };
  nativeBuildInputs = [ emacs ];
  installPhase = ''
    mkdir -p $out/share/emacs/site-lisp/acp
    cp -r ./* $out/share/emacs/site-lisp/acp/
  '';
  meta = with lib; {
    description = "ACP protocol client for Emacs (acp.el)";
    homepage = "https://github.com/xenodium/acp.el";
    license = licenses.mit;
  };
}
