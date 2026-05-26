# Название: modules/pro-services.nix — Базовые сетевые службы и политики доступа
# Кратко: конфигурация NetworkManager, SSH, auditd, AppArmor, fail2ban и
# системные операторские сетевые/дисковые утилиты.
#
# Цель:
#   Предоставить набор проверяемых, безопасных дефолтов для сетевых служб и механизмов контроля
#   на уровне хоста. Изменения, влияющие на открытые порты, оформляются через Change Gate.
#
# Контракт:
#   Опции: networking.networkmanager.enable, services.openssh.settings.* и т.д.
#   Побочные эффекты: при включении открываются порты 22, 80, 443, 53; добавляются systemd-юниты auditd и fail2ban.
#
# Предпосылки:
#   Требуется ядро с поддержкой аудита для auditd; AppArmor может быть не доступен на некоторых системах.
#
# Как проверить (Proof):
#   `systemctl status fail2ban` и `ss -tlnp | grep 22`.
#
# Last reviewed: 2026-05-03
{ pkgs, ... }:

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
  security.audit.backlogLimit = 8192;
  security.audit.rules = [
    "-w /etc/passwd -p wa -k identity"
    "-w /etc/shadow -p wa -k identity"
    "-w /etc/group -p wa -k identity"
    "-a always,exit -F arch=b64 -S execve -k exec"
  ];
  security.auditd.enable = true;

  services.fail2ban = {
    enable = true;
    bantime = "1h";
    maxretry = 6;
  };

  security.apparmor.enable = true;

  environment.systemPackages = with pkgs; [
    iftop
    iotop
    iperf3
    iputils
    dnsutils
    sysstat
    pciutils
    usbutils
    smartmontools
    parted
    dosfstools
    exfatprogs
    ntfs3g
    openssl
  ];

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = [ 53 ];
    trustedInterfaces = [ "docker0" ];
  };

  # Last reviewed update for documentation consistency.
  # Last reviewed: 2026-05-03
}
