# Название: modules/pro-services.nix — Базовые сетевые службы и политики доступа
# Кратко: конфигурация NetworkManager, SSH, auditd, AppArmor и fail2ban с безопасными дефолтами.
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
# Last reviewed: 2026-05-02
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
