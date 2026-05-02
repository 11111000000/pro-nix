# Название: modules/pro-services.nix — Базовые сетевые службы и контроль доступа
# Summary (EN): Network services (NetworkManager, SSH, auditd, fail2ban)
# Цель:
#   Включить базовые сетевые службы (NetworkManager, systemd-resolved), SSH
#   с жёсткими настройками и механизмы контроля (auditd, AppArmor, fail2ban).
# Контракт:
#   Опции: networking.networkmanager.enable, services.openssh.settings.*
#   Побочные эффекты: открывает порты 22, 80, 443, 53; включает firewall;
#   добавляет systemd-юниты auditd, fail2ban, apparmor.
# Предпосылки:
#   Требуется ядро с поддержкой аудита для auditd; AppArmor может отсутствовать
#   в некоторых дистрибутивах.
# Как проверить (Proof):
#   `systemctl status fail2ban`, `ss -tlnp | grep 22`
# Last reviewed: 2026-04-25
{ ... }:

/* RU: Файловый контракт (литературный заголовок) — см. начало файла.
   Этот модуль отвечает за базовые сетевые службы и политики безопасности на уровне хоста.
   Правила:
   - Модуль предоставляет опции для включения/отключения сервисов (networkmanager, ssh, auditd, fail2ban).
   - Модуль не должен форсировать пакеты на top-level: пакеты добавляются через lib.mkDefault.
   - Все изменения, влияющие на открытые порты или правила firewall, требуют Change Gate.
*/

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
