{ stdenv, emacs, lib, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "shell-maker";
  version = "0.93.1";
  src = fetchFromGitHub {
    owner = "xenodium";
    repo = "shell-maker";
    rev = "43ee9e1862994cbaa89715d324edb7a424181f22";
    sha256 = "0bdicj2bclx65n1lx1kwywfksbg1sd02yi03wrklbk56j82mk4ww";
  };
  nativeBuildInputs = [ emacs ];
  installPhase = ''
    mkdir -p $out/share/emacs/site-lisp/shell-maker
    cp -r ./* $out/share/emacs/site-lisp/shell-maker/
  '';
  meta = with lib; {
    description = "Shell maker for agent-shell";
    homepage = "https://github.com/xenodium/shell-maker";
    license = licenses.mit;
  };
}
