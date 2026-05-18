{ pkgs, ... }:

with pkgs;

{
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
  ];
}
