let
  pkgs = import <nixpkgs> {};
in pkgs.stdenv.mkDerivation rec {
  pname = "agent-shell";
  version = "0.0.0";
  src = pkgs.fetchFromGitHub {
    owner = "xenodium";
    repo = "agent-shell";
    rev = "master";
    sha256 = "1zda7sx6y51br1dx50a4m4xrcg4vvsc4iaf19asr1ghgpaf289aw";
  };
  nativeBuildInputs = [ pkgs.emacs ];
  buildInputs = [];
  dontConfigure = true;
  installPhase = ''
    mkdir -p $out/share/emacs/site-lisp/${pname}
    cp -r * $out/share/emacs/site-lisp/${pname}/
    # Do not byte-compile here — many files reference optional dependencies
    # which may not be available at build time. Leave byte-compilation to the
    # user's profile or CI where dependencies are provided by Nix.
    '';
  meta = with pkgs.lib; {
    description = "Agent shell integration (xenodium/agent-shell)";
    homepage = "https://github.com/xenodium/agent-shell";
    license = licenses.mit;
    maintainers = [];
  };
}
