{ stdenv, fetchFromGitHub, emacsPackages }:

emacsPackages.buildEmacsPackage rec {
  pname = "agent-shell";
  version = "0";
  src = fetchFromGitHub {
    owner = "pro-agent";
    repo = "agent-shell";
    rev = "master";
    sha256 = "0000000000000000000000000000000000000000000000000000";
  };
  meta = with stdenv.lib; {
    description = "Agent shell integration";
    homepage = "https://github.com/pro-agent/agent-shell";
    license = licenses.mit;
  };
}
