{ stdenv, fetchFromGitHub, emacsPackages }:

emacsPackages.buildEmacsPackage rec {
  pname = "eldoc-box";
  version = "0.3.0";
  src = fetchFromGitHub {
    owner = "vitalie";
    repo = "eldoc-box";
    rev = "v0.3.0";
    sha256 = "0000000000000000000000000000000000000000000000000000"; # placeholder
  };
  meta = with stdenv.lib; {
    description = "Show eldoc in a childframe/posframe";
    homepage = "https://github.com/vitalie/eldoc-box";
    license = licenses.mit;
  };
}
