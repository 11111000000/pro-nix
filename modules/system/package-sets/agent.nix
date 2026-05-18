{ pkgs, ... }:

with pkgs;

{
  agentPackages = [
    # Local agent/LLM tooling kept as opt-in
    pi.packages.x86_64-linux.coding-agent or null
    # ollama and other local model tooling may be included via this set
  ];
}
