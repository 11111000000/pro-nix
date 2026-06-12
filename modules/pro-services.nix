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
{ pkgs, lib, ... }:

{
  networking.networkmanager.enable = true;
  networking.nameservers = [ "77.88.8.8" "77.88.8.1" "1.1.1.1" "8.8.8.8" ];
  networking.networkmanager.dns = "systemd-resolved";
  # Глобальные дефолты WiFi-соединений: стабилизируют link, сокращают
  # дропы и исключают MAC-ротацию (которая ломает контроль доступа
  # и увеличивает время ассоциации после roam).
  #
  # wifi.powersave: 2 = disable (см. NMSettingWirelessPowersave: 0=DEFAULT,
  #   1=IGNORE, 2=DISABLE, 3=ENABLE). Без этого чип периодически уходит
  #   в firmware-sleep и теряет sync с AP.
  # wifi.scan-rand-mac-address / wifi.cloned-mac-address: "no" = стабильный
  #   MAC. NM по умолчанию рандомизирует MAC при скане (privacy) и при
  #   подключении — на наших AP это лишний overhead и лишний повод для
  #   deauth. Исключаем оба.
  # ipv4/6.dhcp-timeout: жёсткие таймауты, чтобы при микро-разрыве NM не
  #   висел в "connecting" бесконечно.
  networking.networkmanager.settings.connection = {
    "wifi.powersave" = 2;
    "wifi.scan-rand-mac-address" = "no";
    "wifi.cloned-mac-address" = "no";
    "ipv4.dhcp-timeout" = 30;
    "ipv6.dhcp-timeout" = 30;
  };
  # NB: connection.gateway-ping-timeout — не валидный глобальный ключ в
  # NM 1.54 (NM ругается в journal: "unknown key"). Задаётся per-profile
  # через `nmcli con mod` (см. docs/analyse/2026-06-02-network-drops-cf19.md).

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
  security.audit.enable = lib.mkDefault true;
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
    iw
    wirelesstools
  ];

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = [ 53 ];
    # Доверяем docker0 (default bridge) и docker-сети pro-dev, чтобы
    # контейнеры могли ходить к systemd-сервисам на хосте без NAT.
    # NB: docker присваивает bridge-интерфейсу сети `pro-dev` имя вида
    # `br-<hash>` (не `br-pro-dev`). Чтобы не угадывать, разрешаем
    # dev-порты через `trustedInterfaces` — он матчит все docker-мосты
    # и любой br-*. tailscale0 — чтобы dev-сервисы были видны другим
    # участникам tailnet.
    trustedInterfaces = [ "docker0" "tailscale0" "br-+" ];
    # Dev-порты: открыты ТОЛЬКО на loopback/tailnet/docker-bridges, не глобально.
    # 3000 = create-react-app / next.js dev, 5000 = flask, 5173 = vite,
    # 8000 = django / uvicorn, 8080 = common alt-http, 8443 = alt-https.
    # 80/443/22 уже открыты глобально в allowedTCPPorts выше.
    interfaces = {
      lo.allowedTCPPorts = [ 3000 5000 5173 8000 8080 8443 ];
      "tailscale0".allowedTCPPorts = [ 3000 5000 5173 8000 8080 8443 ];
      "docker0".allowedTCPPorts = [ 3000 5000 5173 8000 8080 8443 ];
    };
  };

  # Last reviewed update for documentation consistency.
  # Last reviewed: 2026-05-03
}
