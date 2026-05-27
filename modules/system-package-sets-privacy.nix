{ pkgs, ... }:

with pkgs;

{
  # Privacy tooling belongs to a distinct layer: useful, but operationally
  # expensive and therefore not part of the minimal EXWM baseline.
  privacyPackages = [
    tor
    torsocks
    obfs4
    snowflake
    nyx
    onionshare
    dnscrypt-proxy
    wireguard-tools
    yggdrasil
    i2p
    proxychains
    mullvad-vpn
    # System launcher for Tor Browser
    (writeShellScriptBin "tor-browser" ''
      exec ${pkgs.tor-browser}/bin/tor-browser "$@"
    '')
  ];
}
