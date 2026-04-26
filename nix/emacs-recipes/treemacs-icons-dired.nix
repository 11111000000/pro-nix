{ stdenv, fetchFromGitHub, emacsPackages }:

emacsPackages.buildEmacsPackage rec {
  pname = "treemacs-icons-dired";
  version = "3.0";
  src = fetchFromGitHub {
    owner = "Alexander-Miller";
    repo = "treemacs-icons-dired";
    rev = "v3.0";
    sha256 = "0000000000000000000000000000000000000000000000000000"; # placeholder
  };
  meta = with stdenv.lib; {
    description = "Use treemacs icons in dired";
    homepage = "https://github.com/Alexander-Miller/treemacs-icons-dired";
    license = licenses.mit;
  };
}
