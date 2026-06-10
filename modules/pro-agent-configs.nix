{ config, lib, pkgs, ... }:

let
  cfg = config.pro.agent-configs;

  # Repository root, resolved at eval time so the activation script
  # can `cp` from a stable absolute path under /nix/store.
  repoRoot = ../.;

  # Map of (template path in repo) → (destination under $HOME).
  # Each entry is "relative source" → "xdg-style relative destination".
  templateFiles = [
    {
      src = "local-templates/opencode/opencode.json";
      dst = ".config/opencode/opencode.json";
    }
    {
      src = "local-templates/pi/models.json";
      dst = ".pi/agent/models.json";
    }
  ];

  # Build a list of "if missing, copy" commands.
  copyIfMissingLines = lib.concatMapStringsSep "\n" (entry: ''
    mkdir -p "$HOME/$(dirname "${entry.dst}")"
    if [ ! -e "$HOME/${entry.dst}" ]; then
      cp "${repoRoot}/${entry.src}" "$HOME/${entry.dst}"
      echo "[pro-agent-configs] installed $HOME/${entry.dst}"
    fi
  '') templateFiles;

  # Source the loader from .bashrc so opencode/pi/gptel see AITUNNEL_KEY etc.
  bashrcMarker = "# pro-nix: load AI provider keys from authinfo";
  bashrcSnippet = ''
    ${bashrcMarker}
    [ -f "$HOME/.local/share/pro-nix/load-agent-env.sh" ] && . "$HOME/.local/share/pro-nix/load-agent-env.sh"
  '';
in
{
  options.pro.agent-configs = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Distribute opencode/pi configs from pro-nix repo into $HOME.";
    };

    manageBashrc = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        If true, ensure ~/.bashrc sources the authinfo→env loader script.
        Idempotent: existing marker comment is detected and skipped.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Install the loader script under a stable XDG path.
    home.file.".local/share/pro-nix/load-agent-env.sh" = {
      source = ../scripts/pro-load-agent-env.sh;
      executable = true;
    };

    # Activation: deploy templates that don't yet exist locally.
    # `cp` semantics: never overwrite a user's local edits.
    home.activation.pro-agent-configs-deploy = ''
      #!/bin/sh -e
      ${copyIfMissingLines}
    '';

    # Activation: append a source line to ~/.bashrc (idempotent).
    home.activation.pro-agent-configs-bashrc = lib.mkIf cfg.manageBashrc ''
      #!/bin/sh -e
      bashrc="$HOME/.bashrc"
      marker=${lib.escapeShellArg bashrcMarker}
      if [ -f "$bashrc" ] && ! grep -qF "$marker" "$bashrc"; then
        printf '\n%s\n' ${lib.escapeShellArg bashrcSnippet} >> "$bashrc"
        echo "[pro-agent-configs] appended env-loader source line to $bashrc"
      fi
    '';
  };
}
