{ stdenv, fetchFromGitHub, emacsPackages }:

let pkgs = import <nixpkgs> {};
in pkgs.stdenv.mkDerivation rec {
  pname = "shell-maker";
  version = "0";
  src = fetchFromGitHub {
    owner = "xenodium";
    repo = "shell-maker";
    rev = "master";
    sha256 = "0v2iqvr2ywng5d22sw88k90i2jzl3cf2ybp9q6qpqirhvlsbgq19";
  };
  nativeBuildInputs = [ pkgs.emacs ];
  installPhase = ''
    mkdir -p $out/share/emacs/site-lisp/shell-maker
    cp -r ./* $out/share/emacs/site-lisp/shell-maker/
  '';
  meta = with pkgs.lib; {
    description = "Shell maker for agent-shell";
    homepage = "https://github.com/xenodium/shell-maker";
    license = licenses.mit;
  };
}
