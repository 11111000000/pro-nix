{ ... }:

{
  networking.networkmanager.enable = true;
  networking.nameservers = [ "77.88.8.8" "77.88.8.1" "1.1.1.1" "8.8.8.8" ];
  networking.networkmanager.dns = "systemd-resolved";

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  services.resolved.enable = true;

  # Аудит ядра: включаем auditd для централизованного сбора событий безопасности.
  # Примечание: auditd требует поддержки аудита в ядре; при отсутствии поддержки
  # эта опция будет неэффективна.
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
