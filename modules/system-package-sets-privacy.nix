{ pkgs, ... }:
with pkgs;

{
  # Privacy tooling belongs to a distinct layer: useful, but operationally
  # expensive and therefore not part of the minimal EXWM baseline.
  #
  # NB: `pro-tor` и `torwrap` CLI-утилиты НЕ здесь — они в
  # system-package-sets-tor.nix и подключаются на ВСЕ хосты (включая
  # EXWM-лэптопы). Этот набор — для тяжёлых desktop-профилей.
  privacyPackages = [
    tor
    torsocks
    obfs4
    snowflake
    nyx
    onionshare
    dnscrypt-proxy
    wireguard-tools
    i2p
    proxychains
    mullvad-vpn
    # System launcher for Tor Browser
    (writeShellScriptBin "tor-browser" ''
      exec ${pkgs.tor-browser}/bin/tor-browser "$@"
    '')
  ];
}
