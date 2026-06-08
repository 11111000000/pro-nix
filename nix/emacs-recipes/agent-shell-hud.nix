{ stdenv, emacs, lib }:

stdenv.mkDerivation rec {
  pname = "agent-shell-hud";
  version = "0.1.0";
  src = ../../submodules/agent-shell-hud;

  nativeBuildInputs = [ emacs ];
  dontConfigure = true;
  installPhase = ''
    mkdir -p $out/share/emacs/site-lisp/${pname}
    cp ./*.el $out/share/emacs/site-lisp/${pname}/
  '';
  meta = with lib; {
    description = "HUD/UI extensions for agent-shell: live status, dashboard menu, i18n, side-window info";
    homepage = "https://github.com/11111000000/agent-shell-hud";
    license = licenses.gpl3Plus;
    platforms = platforms.all;
  };
}
