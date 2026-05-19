{ lib, buildNpmPackage, fetchFromGitHub, nodejs_20 }:

buildNpmPackage rec {
  pname = "pi-acp";
  version = "0.0.27";

  src = fetchFromGitHub {
    owner = "svkozak";
    repo = "pi-acp";
    rev = "v${version}";
    hash = "sha256-Bb7qQkELDY175ZNmJD70LzmkcmoQL1LWAnfIxN+ttso=";
  };

  nodejs = nodejs_20;
  npmDepsHash = "sha256-EmzhcvVzrirlKh57Tl4BKVG4XLkAgdaYgdhMfpZVbRI=";

  meta = with lib; {
    description = "ACP adapter for Pi coding agent";
    homepage = "https://github.com/svkozak/pi-acp";
    license = licenses.mit;
    mainProgram = "pi-acp";
  };
}
