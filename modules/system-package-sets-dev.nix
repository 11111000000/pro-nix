{ pkgs, ... }:

with pkgs;

{
  devPackages = [
    git
    curl
    wget
    jq
    just
    shellcheck
    shfmt
    ripgrep
    fd
    findutils
  ];
}
