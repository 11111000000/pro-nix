{ stdenv, emacs, lib }:

stdenv.mkDerivation rec {
  pname = "agent-shell-hud";
  version = "0.1.0";
  src = ../../submodules/agent-shell-hud;

  nativeBuildInputs = [ emacs ];
  dontConfigure = true;
  # Skip the upstream Makefile: its `compile` target is for dev workflows
  # and is broken in bash (single-quote + `\\.el\\'` regex; see
  # submodules/agent-shell-hud Makefile). We only need the .el files in
  # site-lisp; matching the submodule's own flake.nix, which also sets
  # dontBuild = true.
  dontBuild = true;
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
