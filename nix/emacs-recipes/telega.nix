{ stdenv, emacs, lib, pkg-config, withTdlib ? true, tdlib ? null, tdb ? null, glib ? null, zlib ? null, withAppIndicator ? false, libappindicator-gtk3 ? null, ayatana-appindicator3-gtk3 ? null }:

stdenv.mkDerivation rec {
  pname = "telega";
  version = "0.8.632";
  src = ../../submodules/telega.el;

  nativeBuildInputs = [ emacs pkg-config ];
  buildInputs = lib.optionals withTdlib [ tdlib tdb glib zlib ]
    ++ lib.optional (withAppIndicator && libappindicator-gtk3 != null) libappindicator-gtk3;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    # Byte-compile Emacs Lisp files so Emacs loads .elc and skips slow compile.
    emacs --batch -Q -L . -f batch-byte-compile *.el 2>/dev/null || true
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    # Site-lisp must contain *.el / *.elc directly so EMACSLOADPATH entries
    # (`<pkg>/share/emacs/site-lisp`) actually expose the telega features.
    # Previously these were placed under a subdirectory which broke
    # `require 'telega` at runtime.
    mkdir -p $out/share/emacs/site-lisp
    cp *.el  $out/share/emacs/site-lisp/
    cp *.elc $out/share/emacs/site-lisp/ 2>/dev/null || true
    runHook postInstall
  '';

  meta = with lib; {
    description = "Telegram client for Emacs (zevlg/telega.el fork via submodule)";
    homepage = "https://github.com/zevlg/telega.el";
    license = licenses.gpl3Plus;
  };
}
