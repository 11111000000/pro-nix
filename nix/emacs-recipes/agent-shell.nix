{ stdenv, fetchFromGitHub, emacs, lib }:

stdenv.mkDerivation rec {
  pname = "agent-shell";
  version = "0.0.0";
  src = fetchFromGitHub {
    owner = "xenodium";
    repo = "agent-shell";
    rev = "master";
    sha256 = "1zda7sx6y51br1dx50a4m4xrcg4vvsc4iaf19asr1ghgpaf289aw";
  };
  nativeBuildInputs = [ emacs ];
  buildInputs = [];
  dontConfigure = true;
  installPhase = ''
    mkdir -p $out/share/emacs/site-lisp/${pname}
    cp -r ./* $out/share/emacs/site-lisp/${pname}/
  '';
  meta = with lib; {
    description = "Agent shell integration (xenodium/agent-shell)";
    homepage = "https://github.com/xenodium/agent-shell";
    license = licenses.mit;
  };
}
