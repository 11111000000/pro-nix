{ pkgs, ... }:

{
  # Agent tooling stays intentionally empty for now: the package boundary is
  # reserved, but the actual agent stack should be injected by host composition
  # once the dependency graph is explicit and testable.
  agentPackages = [ ];
}
