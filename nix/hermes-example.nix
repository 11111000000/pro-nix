{ lib, pkgs, ... }:

{
  # Example: a small hermes service config that hosts can import to enable Hermes.
  # This file is intentionally minimal — users should adapt environmentFiles and
  # secrets according to their ops workflow.

  imports = [];

  services.hermes-agent = {
    enable = true;
    # Use a basic config that is safe for local usage. Operators must set secrets
    # via environmentFiles (not stored in Nix store).
    config = {
      model = { provider = "openrouter"; default = "anthropic/claude-opus-4.6"; };
      terminal = { backend = "local"; timeout = 180; };
      toolsets = [ "all" ];
    };
    environmentFiles = [ "/run/secrets/hermes-env" ];
    extraPackages = with pkgs; [ jq ripgrep curl ];
  };

}
