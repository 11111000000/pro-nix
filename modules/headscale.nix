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
    # Prefer native headscale package over docker by default.
    environment.systemPackages = lib.mkDefault (with pkgs; [ headscale ]);

    # Minimal native systemd service. Operator should override config.yaml in host overlay.
    systemd.services.headscale = {
      description = "Headscale (WireGuard control plane)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.headscale}/bin/headscale serve --config /etc/headscale/config.yaml";
        Restart = "on-failure";
        PrivateTmp = "true";
      };
    };

    environment.etc."headscale/config.yaml".text = ''
    # Minimal headscale config. Operator: override in host overlay at /etc/headscale/config.yaml
    server_url: "http://0.0.0.0:8080"
    listen: "0.0.0.0:8080"
    db_type: "sqlite3"
    db_path: "/var/lib/headscale/headscale.db"
    '';

    systemd.tmpfiles.rules = [ "d /var/lib/headscale 0755 root root -" ];
  };
}
