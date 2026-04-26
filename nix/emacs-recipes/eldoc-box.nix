{ stdenv, fetchFromGitHub, emacsPackages }:

emacsPackages.buildEmacsPackage rec {
  pname = "eldoc-box";
  version = "0.3.0";
  src = fetchFromGitHub {
    owner = "casouri";
    repo = "eldoc-box";
    rev = "2680a08ff2438ff8c2ea6f8d57f22095f857900c";
    sha256 = "1iqha79lpydaz2i5dah11zsj060bs1livl3fpi76kh3j5ak6v5id";
  };
  meta = with stdenv.lib; {
    description = "Show eldoc in a childframe/posframe";
    homepage = "https://github.com/vitalie/eldoc-box";
    license = licenses.mit;
  };
}
