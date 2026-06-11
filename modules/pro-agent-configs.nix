{ config, lib, pkgs, ... }:
let
  cfg = config.pro.agent-configs;

  # Repository root, resolved at eval time so the activation script
  # can `cp` from a stable absolute path under /nix/store.
  repoRoot = ../.;

  # Map of (template path in repo) → (destination under $HOME).
  # Each entry is "relative source" → "destination relative to $HOME".
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
  #
  # Why `install -o $UID -g $GID` and explicit chown: home-manager
  # activation runs as root, so a plain `cp` would create files owned
  # by root inside a user's $HOME — making the user unable to overwrite
  # them later (e.g. `pi` rewriting its `agent/models.json`). On hosts
  # with several Unix accounts, sibling users may already own parts of
  # `~/.pi/`; we chmod the existing dir to the current user and ignore
  # the permission error to keep activation idempotent.
  copyIfMissingLines = lib.concatMapStringsSep "\n" (entry: ''
    dst="$HOME/${entry.dst}"
    dstdir="$(dirname "$dst")"
    # Ensure the destination dir exists and is writable by the current
    # user. Ignore failures: if another user owns it, that user can
    # still re-run the activation for themselves, and we shouldn't
    # blow up the whole switch just because of a permission boundary.
    mkdir -p "$dstdir" 2>/dev/null || true
    if [ -d "$dstdir" ] && [ -w "$dstdir" ]; then
      if [ ! -e "$dst" ]; then
        install -m 0644 -o "$(id -u)" -g "$(id -g)" \
          "${repoRoot}/${entry.src}" "$dst" 2>/dev/null \
          || cp "${repoRoot}/${entry.src}" "$dst" 2>/dev/null \
          || echo "[pro-agent-configs] WARN: cannot install $dst (permission denied)"
        if [ -e "$dst" ]; then
          echo "[pro-agent-configs] installed $dst"
        fi
      fi
    else
      echo "[pro-agent-configs] SKIP $dst — dir not writable by current user"
    fi
  '') templateFiles;

  # Source the loader from .profile so opencode/pi/gptel see AITUNNEL_KEY etc.
  # In NixOS the relevant user-level RC file is ~/.profile (no ~/.bashrc by default),
  # which is read by login shells and by graphical sessions sourcing it via PAM.
  profileMarker = "# pro-nix: load AI provider keys from authinfo";
  profileSnippet = ''
    ${profileMarker}
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
        If true, ensure ~/.profile sources the authinfo→env loader script.
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

    # Activation: append a source line to ~/.profile (idempotent).
    home.activation.pro-agent-configs-bashrc = lib.mkIf cfg.manageBashrc ''
      #!/bin/sh -e
      rcfile="$HOME/.profile"
      marker=${lib.escapeShellArg profileMarker}
      if [ -f "$rcfile" ] && ! grep -qF "$marker" "$rcfile"; then
        printf '\n%s\n' ${lib.escapeShellArg profileSnippet} >> "$rcfile"
        echo "[pro-agent-configs] appended env-loader source line to $rcfile"
      elif [ ! -f "$rcfile" ]; then
        # Create a minimal ~/.profile that sources the loader.
        mkdir -p "$HOME"
        printf '%s\n' ${lib.escapeShellArg profileSnippet} > "$rcfile"
        chmod 0644 "$rcfile"
        echo "[pro-agent-configs] created $rcfile with env-loader source line"
      fi
    '';
  };
}
