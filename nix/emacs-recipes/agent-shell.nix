{ stdenv, fetchFromGitHub, emacsPackages }:

emacsPackages.buildEmacsPackage rec {
  pname = "agent-shell";
  version = "0";
  src = fetchFromGitHub {
    owner = "xenodium";
    repo = "agent-shell";
    rev = "master";
    sha256 = "1zda7sx6y51br1dx50a4m4xrcg4vvsc4iaf19asr1ghgpaf289aw";
  };
  meta = with stdenv.lib; {
    description = "Agent shell integration";
    homepage = "https://github.com/pro-agent/agent-shell";
    license = licenses.mit;
  };
}
