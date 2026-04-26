{ stdenv, fetchFromGitHub }:

let pkgs = import <nixpkgs> {};
in pkgs.stdenv.mkDerivation rec {
  pname = "acp";
  version = "0";
  src = fetchFromGitHub {
    owner = "xenodium";
    repo = "acp.el";
    rev = "master";
    sha256 = "0hr1176sy8xrx6wkqadmvwdjm1sv7aq8ddrw8h3ha6sn74glx8ws";
  };
  nativeBuildInputs = [ pkgs.emacs ];
  installPhase = ''
    mkdir -p $out/share/emacs/site-lisp/acp
    cp -r ./* $out/share/emacs/site-lisp/acp/
  '';
  meta = with pkgs.lib; {
    description = "ACP protocol client for Emacs (acp.el)";
    homepage = "https://github.com/xenodium/acp.el";
    license = licenses.mit;
  };
}
