{ stdenv, emacs, lib }:

stdenv.mkDerivation rec {
  pname = "telega";
  version = "0.8.632";
  src = ../../submodules/telega.el;

  nativeBuildInputs = [ emacs ];
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    emacs --batch -Q -L . -f batch-byte-compile *.el 2>/dev/null || true
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/emacs/site-lisp/${pname}
    cp *.el  $out/share/emacs/site-lisp/${pname}/
    cp *.elc $out/share/emacs/site-lisp/${pname}/ 2>/dev/null || true
    runHook postInstall
  '';

  meta = with lib; {
    description = "Telegram client for Emacs (zevlg/telega.el fork via submodule)";
    homepage = "https://github.com/zevlg/telega.el";
    license = licenses.gpl3Plus;
  };
}
