{ stdenv, fetchFromGitHub, emacs, lib }:

stdenv.mkDerivation rec {
  pname = "agent-shell";
  version = "0.0.0";
  src = fetchFromGitHub {
    owner = "xenodium";
    repo = "agent-shell";
    rev = "411c9042f1ea55ee515c7e5918e056fe3ff1f2a8";
    sha256 = "1q1v8kczvsdcwlddivayfvdzpyj0ad3rn49a1pynr1dvxamdq5gx";
  };
  nativeBuildInputs = [ emacs ];
  buildInputs = [];
  propagatedBuildInputs = [];
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
