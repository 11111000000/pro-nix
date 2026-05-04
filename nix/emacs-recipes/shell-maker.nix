{ stdenv, fetchFromGitHub, emacsPackages }:

let pkgs = import <nixpkgs> {};
in pkgs.stdenv.mkDerivation rec {
  pname = "shell-maker";
  version = "0";
  src = fetchFromGitHub {
    owner = "xenodium";
    repo = "shell-maker";
    rev = "master";
    sha256 = "09lgcvcvnrkfxg47m844177c1cns2qjkjv34lpn1k6pakias6xrn";
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
