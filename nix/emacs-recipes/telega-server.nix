{ stdenv, lib, tdlib, pkg-config, tdb, glib, zlib, withAppIndicator ? false, libappindicator-gtk3 ? null, ayatana-appindicator3-gtk3 ? null }:

stdenv.mkDerivation rec {
  pname = "telega-server";
  version = "0.8.632";

  src = ../../submodules/telega.el/server;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ tdlib tdb glib zlib ]
    ++ lib.optional (withAppIndicator && libappindicator-gtk3 != null) libappindicator-gtk3;

  makeFlags = lib.optionals (withAppIndicator && libappindicator-gtk3 != null) [ "WITH_APPINDICATOR=1" ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 telega-server $out/bin/telega-server
    runHook postInstall
  '';

  meta = with lib; {
    description = "telega-server (TDLib JSON server) for telega.el";
    homepage = "https://github.com/zevlg/telega.el";
    license = licenses.gpl3Plus;
    platforms = platforms.unix;
  };
}
