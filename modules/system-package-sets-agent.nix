{ pkgs, ... }:

{
  # Agent tooling is reserved as a separate boundary, but not populated yet.
  # This keeps the composition honest: the minimal host does not inherit any
  # hidden agent runtime until we wire it explicitly at host level.
  agentPackages = [ ];
}
