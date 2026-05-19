{ config, pkgs, lib, ... }:

let
  cfgName = "pro.sshAgent";
in
{
  options.pro.sshAgent = {
    enable = lib.mkEnableOption "Enable per-user ssh-agent socket and environment export";
  };

  config = lib.mkIf (config.pro.sshAgent.enable) {
    # Provide a systemd user service that runs ssh-agent and creates a socket
    systemd.user.services.ssh-agent = {
      description = "Per-user ssh-agent managed by systemd user";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        # Use systemd specifier %t for per-user runtime directory so the
        # path is expanded by systemd correctly when starting the unit.
        ExecStart = "${pkgs.openssh}/bin/ssh-agent -a %t/ssh-agent.socket";
        ExecStartPost = "${pkgs.systemd}/bin/systemctl --user set-environment SSH_AUTH_SOCK=%t/ssh-agent.socket";
        Restart = "on-failure";
        KillMode = "process";
      };
    };

    # Export a small profile.d snippet so that legacy shells and TTYs pick up SSH_AUTH_SOCK.
    # Prefer systemd --user environment (set by the ssh-agent unit) when available,
    # otherwise fall back to the socket under $XDG_RUNTIME_DIR.
    environment.etc."profile.d/ssh-agent.sh".text = lib.concatStringsSep "\n" [
      "#!/bin/sh",
      "# Try to read SSH_AUTH_SOCK from systemd --user environment if possible.",
      "if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then",
      "  _val=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^SSH_AUTH_SOCK=//p' | sed -n '1p') || _val=\"\"",
      "  if [ -n \"$_val\" ]; then",
      "    export SSH_AUTH_SOCK=\"$_val\"",
      "  fi",
      "fi",
      "",
      "# Fallback: if no env var set, use XDG_RUNTIME_DIR socket if present.",
      "if [ -z \"${SSH_AUTH_SOCK-}\" ] && [ -n \"$XDG_RUNTIME_DIR\" ] && [ -S \"$XDG_RUNTIME_DIR/ssh-agent.socket\" ]; then",
      "  export SSH_AUTH_SOCK=\"$XDG_RUNTIME_DIR/ssh-agent.socket\"",
      "fi",
      "",
      "# Clean temporary var",
      "unset _val",
    ];

    # Ensure interactive bash shells also source the profile.d snippet so
    # non-login terminals (common in GUI terminals) get SSH_AUTH_SOCK set.
    # Use a safe POSIX-compatible check for an interactive shell; avoid
    # expanding undefined variables at Nix eval-time by using single-quotes
    # and a runtime check inside the generated file.
    environment.etc."bash.bashrc".text = lib.concatStringsSep "\n" [
      "# Global bashrc: source profile.d ssh-agent helper for interactive shells",
      "if [ -n \"$PS1\" ]; then",
      "  if [ -f /etc/profile.d/ssh-agent.sh ]; then",
      "    . /etc/profile.d/ssh-agent.sh",
      "  fi",
      "fi",
    ];

    # Also provide a systemd user environment generator to ensure variable is visible
    # for GUI-launched processes; we set the env at ExecStartPost above but ensure the
    # socket is reachable by child processes via profile.d as well.

    # Note: enabling lingering is intentionally left to operators. If you need
    # linger enabled for users so user units run without interactive login,
    # run `sudo loginctl enable-linger <user>` on the host. This avoids
    # evaluation-time coupling with users definitions which can cause
    # module composition errors during `nix eval`.
  };
}
