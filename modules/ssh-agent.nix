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
        ExecStart = "${pkgs.openssh}/bin/ssh-agent -a $XDG_RUNTIME_DIR/ssh-agent.socket";
        ExecStartPost = "${pkgs.systemd}/bin/systemctl --user set-environment SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent.socket";
        Restart = "on-failure";
        KillMode = "process";
      };
    };

    # Ensure the user service is enabled for each user via user units
    systemd.user.defaultDependencies = true;

    # Export a small profile.d snippet so that legacy shells and TTYs pick up SSH_AUTH_SOCK
    environment.etc."profile.d/ssh-agent.sh".text = ''
#!/bin/sh
# Export SSH_AUTH_SOCK if the per-user ssh-agent socket exists
if [ -n "${'$'}XDG_RUNTIME_DIR" ] && [ -S "${'$'}XDG_RUNTIME_DIR/ssh-agent.socket" ]; then
  export SSH_AUTH_SOCK="${'$'}XDG_RUNTIME_DIR/ssh-agent.socket"
fi
'';

    # Also provide a systemd user environment generator to ensure variable is visible
    # for GUI-launched processes; we set the env at ExecStartPost above but ensure the
    # socket is reachable by child processes via profile.d as well.
  };
}
