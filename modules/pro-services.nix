{ ... }:

{
  networking.networkmanager.enable = true;
  networking.nameservers = [ "77.88.8.8" "77.88.8.1" "1.1.1.1" "8.8.8.8" ];
  networking.networkmanager.dns = "systemd-resolved";

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  services.resolved.enable = true;

  # Enable kernel auditing and auditd service so we can collect audit logs.
  # auditd is lightweight but requires kernel audit support; enabling helps security visibility.
  security.audit.enable = true;
  security.auditd.enable = true;

  services.fail2ban = {
    enable = true;
    bantime = "1h";
    maxretry = 6;
  };

  security.apparmor.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = [ 53 ];
    trustedInterfaces = [ "docker0" ];
  };
}
