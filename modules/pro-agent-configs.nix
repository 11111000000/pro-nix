{ config, lib, pkgs, piPkg, ... }:
let
  cfg = config.pro.agent-configs;

  # Repository root, resolved at eval time so the activation script
  # can `cp` from a stable absolute path under /nix/store.
  repoRoot = ../.;

  # Built-in subagent extension lives in pi-coding-agent's nix store.
  # We symlink (not copy) so updates to pi-coding-agent flow through.
  subagentExtSrc = "${piPkg}/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions/subagent";

  # Map of (template path in repo) → (destination under $HOME).
  # Each entry is "relative source" → "destination relative to $HOME".
  #
  # IMPORTANT: this only covers single-file templates. Whole directories
  # (skills/, agents/, prompts/, extensions/pi-permission-system/) are
  # handled by `treeDeploy` below.
  templateFiles = [
    {
      src = "local-templates/opencode/opencode.json";
      dst = ".config/opencode/opencode.json";
    }
    {
      src = "local-templates/pi/models.json";
      dst = ".pi/agent/models.json";
    }
    {
      src = "local-templates/pi/mcp.json";
      dst = ".pi/agent/mcp.json";
    }
    {
      src = "local-templates/pi/settings.json";
      dst = ".pi/agent/settings.json";
    }
    {
      src = "local-templates/kimi-code/mcp.json";
      dst = ".kimi-code/mcp.json";
    }
  ];

  # Directory trees to deploy (if any file is missing, copy the whole tree).
  # Each entry: "relative source under repoRoot" → "destination under $HOME".
  treeTemplates = [
    {
      src = "local-templates/pi/skills";
      dst = ".pi/agent/skills";
    }
    {
      src = "local-templates/pi/agents";
      dst = ".pi/agent/agents";
    }
    {
      src = "local-templates/pi/prompts";
      dst = ".pi/agent/prompts";
    }
    {
      src = "local-templates/pi/extensions";
      dst = ".pi/agent/extensions";
    }
    {
      src = "local-templates/opencode/skills";
      dst = ".config/opencode/skills";
    }
  ];

  # Build a list of "if missing, copy" commands for single files.
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

  # Recursive tree deploy: if any file under dst/ is missing, copy the
  # whole tree. We check for a sentinel file (.pro-nix-marker) per dir
  # to make this idempotent and cheap.
  copyTreesLines = lib.concatMapStringsSep "\n" (entry: ''
    src_tree="${repoRoot}/${entry.src}"
    dst_tree="$HOME/${entry.dst}"
    if [ -d "$src_tree" ]; then
      mkdir -p "$dst_tree" 2>/dev/null || true
      if [ -d "$dst_tree" ] && [ -w "$dst_tree" ]; then
        # Copy missing files (don't overwrite user's local edits)
        # Use find to walk and rsync-style --ignore-existing semantics via cp -n
        (cd "$src_tree" && find . -type f) | while IFS= read -r rel; do
          src_file="$src_tree/$rel"
          dst_file="$dst_tree/$rel"
          dst_file_dir="$(dirname "$dst_file")"
          if [ ! -e "$dst_file" ]; then
            mkdir -p "$dst_file_dir" 2>/dev/null || true
            install -m 0644 -o "$(id -u)" -g "$(id -g)" \
              "$src_file" "$dst_file" 2>/dev/null \
              || cp "$src_file" "$dst_file" 2>/dev/null \
              || echo "[pro-agent-configs] WARN: cannot install $dst_file"
          fi
        done
        echo "[pro-agent-configs] synced tree $dst_tree"
      else
        echo "[pro-agent-configs] SKIP tree $dst_tree — not writable"
      fi
    fi
  '') treeTemplates;

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

    installSubagentExtension = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        If true, symlink pi-mono's built-in `subagent` extension
        (examples/extensions/subagent/) into ~/.pi/agent/extensions/.
        Required for slash-commands `/implement`, `/scout-and-plan`,
        `/implement-and-review`, and the parallel-checklist skill.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Install the loader script under a stable XDG path.
    home.file.".local/share/pro-nix/load-agent-env.sh" = {
      source = ../scripts/pro-load-agent-env.sh;
      executable = true;
    };

    # Activation: deploy single-file templates that don't yet exist locally.
    # `cp` semantics: never overwrite a user's local edits.
    home.activation.pro-agent-configs-deploy = ''
      #!/bin/sh -e
      ${copyIfMissingLines}
    '';

    # Activation: deploy directory trees (skills/, agents/, prompts/, extensions/).
    # Same "if missing, copy" semantics as the single-file deploy above.
    home.activation.pro-agent-configs-trees = ''
      #!/bin/sh -e
      ${copyTreesLines}
    '';

    # Activation: symlink pi-mono's built-in subagent extension so
    # slash-commands /implement, /scout-and-plan, /implement-and-review
    # work, and the `subagent` tool is exposed to the parent agent.
    home.activation.pro-agent-configs-subagent-symlink = lib.mkIf cfg.installSubagentExtension ''
      #!/bin/sh -e
      subagent_dst="$HOME/.pi/agent/extensions/subagent"
      subagent_src="${subagentExtSrc}"
      if [ -d "$subagent_src" ]; then
        mkdir -p "$subagent_dst" 2>/dev/null || true
        if [ -d "$subagent_dst" ] && [ -w "$subagent_dst" ]; then
          ln -sfn "$subagent_src/index.ts"  "$subagent_dst/index.ts"  2>/dev/null \
            && echo "[pro-agent-configs] symlinked subagent/index.ts"
          ln -sfn "$subagent_src/agents.ts" "$subagent_dst/agents.ts" 2>/dev/null \
            && echo "[pro-agent-configs] symlinked subagent/agents.ts"
        else
          echo "[pro-agent-configs] SKIP subagent symlink — dir not writable"
        fi
      else
        echo "[pro-agent-configs] WARN: subagent source not found: $subagent_src"
        echo "  (rebuild after pi-mono update)"
      fi
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
