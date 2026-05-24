{ pkgs, ... }:

with pkgs;

{
  # Minimal runtime packages required by all hosts
  runtimePackages = [
    bashInteractive
    openssh
    python3
    coreutils
    procps
    dbus
    gawk
    kbd
    mc
    emacs
    nodePackages.mermaid-cli
    # opencode removed from the runtime set: it is delivered via the
    # Home Manager wrapper path, not system runtime.
  ];
}
