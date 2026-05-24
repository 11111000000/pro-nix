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
    # Real opencode binary — работает напрямую (для ACP/MCP) и как основа
    # для programs.opencode-bwrap (sandboxed HM wrapper).
    opencode
  ];
}
