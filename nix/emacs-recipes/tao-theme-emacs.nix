{ stdenv, emacs, lib, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "tao-theme-emacs";
  version = "1.1.3";
  src = fetchFromGitHub {
    owner = "11111000000";
    repo = "tao-theme-emacs";
    rev = "33c0d44048afe444e7a8aee30fbc101a00453799";
    sha256 = "sha256-i2XR5k3F3Dys3iOYnth2ov/HSkr6mFr9Sbq09KS0Q6E=";
  };

  nativeBuildInputs = [ emacs ];
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    emacs --batch -Q -L . -f batch-byte-compile tao-theme.el tao-yang-theme.el tao-yin-theme.el 2>/dev/null || true
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/emacs/site-lisp/${pname}
    cp ./*.el $out/share/emacs/site-lisp/${pname}/
    cp ./*.elc $out/share/emacs/site-lisp/${pname}/ 2>/dev/null || true
    cp -r images $out/share/emacs/site-lisp/${pname}/
    runHook postInstall
  '';

  meta = with lib; {
    description = "tao-theme-emacs (11111000000/tao-theme-emacs fork)";
    homepage = "https://github.com/11111000000/tao-theme-emacs";
    license = licenses.mit;
  };
}
