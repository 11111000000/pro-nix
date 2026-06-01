{ stdenv, emacs, lib }:

stdenv.mkDerivation rec {
  pname = "agent-shell";
  version = "0.0.0";
  src = ../../submodules/agent-shell;

  nativeBuildInputs = [ emacs ];
  dontConfigure = true;
  installPhase = ''
    mkdir -p $out/share/emacs/site-lisp/${pname}
    cp ./*.el $out/share/emacs/site-lisp/${pname}/
  '';
  meta = with lib; {
    description = "Agent shell integration (11111000000/agent-shell fork)";
    homepage = "https://github.com/11111000000/agent-shell";
    license = licenses.mit;
  };
}