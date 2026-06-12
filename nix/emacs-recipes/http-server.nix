{ stdenv, fetchFromCodeberg, trivialBuild }:

# http-server.el: minimal HTTP/1.1 + WebSocket server for Emacs, lives on
# Codeberg. Нет в nixpkgs — подтягиваем напрямую с Codeberg по аналогии
# с recipes/eldoc-box.nix. MELPA-recipe: (:fetcher codeberg :repo
# "martenlienen/http-server.el"); пин на коммит 4285bd3e4b67983cb783f46afc736032f895882d
# (HEAD main, 2026-06-09).
#
# Используем `trivialBuild` из emacsPackages — `buildEmacsPackage` в
# nixpkgs 25.11 удалён (см. nix/overlays/emacs-extra.nix:43).
trivialBuild rec {
  pname = "http-server";
  version = "unstable-2026-06-09";
  src = fetchFromCodeberg {
    owner = "martenlienen";
    repo = "http-server.el";
    rev = "4285bd3e4b67983cb783f46afc736032f895882d";
    sha256 = "sha256-3cb2f7991da3c9ebf37095ea7df626213b9c744f2ba90501a317ab6c419f2a7a=";
  };
  meta = with stdenv.lib; {
    description = "Speaks HTTP for you — minimal HTTP/1.1 + WebSocket server for Emacs";
    homepage = "https://codeberg.org/martenlienen/http-server.el";
    license = licenses.gpl3Plus;
  };
}
