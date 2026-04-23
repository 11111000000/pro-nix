# Файл: автосгенерированная шапка — комментарии рефакторятся
{ config, pkgs, lib, ... }:

let
  cfg = {};
in

{
  options = {
    headscale = {
      enable = lib.mkEnableOption "Enable Headscale service (control plane for WireGuard)";
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0:8080";
        description = "Address Headscale listens on";
      };
    };
  };

  config = lib.mkIf config.headscale.enable {
    environment.systemPackages = lib.mkForce (config.environment.systemPackages or []) ++ with pkgs; [ docker ];
    systemd.services.headscale = {
      description = "Headscale (WireGuard control plane)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.docker}/bin/docker run --rm -p ${config.headscale.listenAddress} -v /var/lib/headscale:/data headscale/headscale";
        Restart = "on-failure";
      };
    };
  };
}
