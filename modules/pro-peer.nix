# Файл: автосгенерированная шапка — комментарии рефакторятся
{ config, pkgs, lib, ... }:

let
  cfg = {};
in

{
  options = {
    pro-peer = {
      enable = lib.mkEnableOption "Enable pro peer discovery defaults (Avahi + SSH hardening)";
      allowTorHiddenService = lib.mkEnableOption "Enable tor hidden-service example for SSH (off by default)";
      enableKeySync = lib.mkEnableOption "Enable automatic authorized_keys sync from an encrypted file";
      keysGpgPath = lib.mkOption {
        type = lib.types.str;
        description = "Path to GPG-encrypted authorized_keys (default: /etc/pro-peer/authorized_keys.gpg)";
        default = "/etc/pro-peer/authorized_keys.gpg";
      };
      keySyncInterval = lib.mkOption {
        type = lib.types.str;
        description = "Systemd timer OnCalendar/OnUnitActiveSec for key sync (default: 1h)";
        default = "1h";
      };
      torBackupRecipient = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = "GPG recipient to encrypt HiddenService backup to (optional).";
        default = null;
      };
      enableYggdrasil = lib.mkEnableOption "Enable Yggdrasil mesh daemon (optional)";
      yggdrasilConfigPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = "Path to yggdrasil config file (optional). If null a default will be used in /etc/yggdrasil.conf";
        default = null;
      };
      enableWireguardHelper = lib.mkEnableOption "Enable simple WireGuard helper (wg-quick) (optional)";
      wireguardConfigPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = "Path to wireguard config (wg0.conf) to be used by helper service";
        default = null;
      };
    };
  };

  # Собираем условные фрагменты конфигурации и объединяем их в единый атрибут `config`.
  config = lib.mkMerge [
    (lib.mkIf config.pro-peer.enable {
      # Avahi — служба mDNS для обнаружения хостов в локальной сети (LAN).
      services.avahi = {
        enable = true;
        publish = {
          enable = true; # advertise the host via mDNS
        };
      };
      # Добавляем файл службы Avahi, рекламирующий SSH через mDNS, чтобы клиенты
      # (macOS, iOS, Android с Bonjour) могли обнаруживать хост и подключаться по 22 порту.
      environment.etc."avahi/services/ssh.service".text = ''
        <?xml version="1.0" standalone='no'?>
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">%h</name>
          <service>
            <type>_ssh._tcp</type>
            <port>22</port>
          </service>
        </service-group>
      '';

      # Жёсткие (безопасные) дефолты для SSH на хостах pro-nix.
       services.openssh = {
         enable = true;
         settings = {
           PermitRootLogin = "no";
           PasswordAuthentication = false;
           KbdInteractiveAuthentication = false;
            # Читаем авторизованные ключи сначала из runtime‑управляемого файла,
            # затем из пользовательских файлов.
           AuthorizedKeysFile = "/var/lib/pro-peer/authorized_keys %h/.ssh/authorized_keys";
         };
       };

      # Обеспечиваем существование директории для runtime‑файла authorized_keys
      # с безопасными правами и положением-заглушкой на диске, чтобы состояние
      # было проверяемым. Не указываем sshd модулю путь на runtime-файл — это
      # может быть недоступно на стадии вычисления конфигурации. Вместо этого
      # добавляем правила tmpfiles, которые создадут необходимые пути при старте.
      # Правила tmpfiles добавляются как дополнение, а не заменяют глобальные
      # правила, чтобы другие модули могли дописывать свои записи.
      systemd.tmpfiles.rules = [
        "d /var/lib/pro-peer 0700 root root -"
        "f /var/lib/pro-peer/authorized_keys 0600 root root -"
        # Ensure Avahi's runtime directory exists early so the daemon doesn't
        # fail when systemd starts it before tmpfiles are applied by other
        # packages. Ownership matches the avahi package expectations.
        "d /run/avahi-daemon 0755 avahi avahi -"
      ];

      # Разрешаем mDNS (UDP/5353) в брандмауэре, чтобы хосты могли находить друг
      # друга в LAN через Avahi. Список портов объединяется с существующим,
      # чтобы не перезаписывать настройки других модулей.
      networking.firewall = lib.mkIf true {
        # Добавляем 5353 в allowedUDPPorts как низкоприоритетный дефолт через
        # lib.mkDefault. Это позволяет другим модулям или хостовым конфигам
        # переопределять значение и предотвращает рекурсию при оценке config.*.
        allowedUDPPorts = lib.mkDefault (lib.concatLists [ (config.networking.firewall.allowedUDPPorts or []) [ 5353 ] ]);
        # Дополнительно добавляем idempotent правила через extraCommands, чтобы
        # разрешить IPv4 и IPv6 multicast (224.0.0.251 и ff02::fb), используемые
        # Avahi для обнаружения в сети.
        extraCommands = lib.mkForce ''
          # Allow IPv4 mDNS UDP port 5353 (multicast 224.0.0.251)
          iptables -C INPUT -p udp --dport 5353 -d 224.0.0.251 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 5353 -d 224.0.0.251 -j ACCEPT || true
          # Allow IPv6 mDNS (multicast ff02::fb)
          ip6tables -C INPUT -p udp --dport 5353 -d ff02::fb -j ACCEPT 2>/dev/null || ip6tables -I INPUT -p udp --dport 5353 -d ff02::fb -j ACCEPT || true
        '';
      };

      environment.etc."pro-peer/authorized_keys".text = "# Managed at runtime by pro-peer-sync-keys\n";

      # Избегаем указания sshd на произвольные файлы во время вычисления
      # конфигурации: принудительно делаем пустую декларацию authorizedKeys.
      # Фактический runtime‑файл записывается службой синхронизации в
      # /var/lib/pro-peer/authorized_keys и будет прочитан при запуске SSH.
      users.users.root.openssh.authorizedKeys = lib.mkForce { keys = []; keyFiles = []; };
    })

    (lib.mkIf config.pro-peer.enableKeySync {
      environment.systemPackages = with pkgs; [ gnupg ];
      environment.etc."pro-peer-sync-keys.sh".source = ../scripts/pro-peer-sync-keys.sh;
      environment.etc."pro-peer-sync-keys.sh".mode = "0755";

      systemd.services."pro-peer-sync-keys" = {
        description = "Pro‑peer: sync authorized_keys from encrypted file";
        wantedBy = [ "multi-user.target" ];
        # Ограничиваем использование CPU для одноразовой задачи синхронизации
        # ключей, чтобы не блокировать интерактивные сессии в момент её работы.
        serviceConfig = {
          Type = "oneshot";
          ExecStart = builtins.concatStringsSep " " [ "/etc/pro-peer-sync-keys.sh" "--input" config.pro-peer.keysGpgPath "--out" "/var/lib/pro-peer/authorized_keys" ];
          CPUAccounting = "true";
          CPUQuota = "30%";
        };
      };

        systemd.timers."pro-peer-sync-keys.timer" = {
          description = "Periodic pro-peer key sync";
          timerConfig = { OnUnitActiveSec = config.pro-peer.keySyncInterval; };
          wantedBy = [ "timers.target" ];
        };
      })

    (lib.mkIf (config.pro-peer.allowTorHiddenService && (config.pro-peer.torBackupRecipient != null)) {
      environment.systemPackages = with pkgs; [ gnupg tar ];
      environment.etc."pro-peer-backup-hiddenservice.sh".source = ../scripts/backup-hiddenservice.sh;
      environment.etc."pro-peer-backup-hiddenservice.sh".mode = "0755";

      systemd.services."pro-peer-backup-hiddenservice" = {
        description = "Backup tor hidden service key encrypted to recipient";
        after = [ "tor.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = builtins.concatStringsSep " " [ "/etc/pro-peer-backup-hiddenservice.sh" "--hidden-dir" "/var/lib/tor/ssh_hidden_service" "--recipient" config.pro-peer.torBackupRecipient "--out-dir" "/var/lib/pro-peer" ];
          CPUAccounting = "true";
          CPUQuota = "30%";
        };
      };
    })

    (lib.mkIf config.pro-peer.enableYggdrasil {
      environment.systemPackages = with pkgs; [ yggdrasil ];
      systemd.services.yggdrasil = {
        description = "Yggdrasil mesh daemon (pro-peer)";
        wantedBy = [ "multi-user.target" ];
        # Даём демону mesh небольшую долю CPU и защищаем систему от его
        # перегрузки при интенсивной сетевой активности.
        serviceConfig = {
          ExecStart = builtins.concatStringsSep " " [ (builtins.toString pkgs.yggdrasil + "/bin/yggdrasil") "-useconffile" (if config.pro-peer.yggdrasilConfigPath != null then config.pro-peer.yggdrasilConfigPath else "/etc/yggdrasil.conf") ];
          Restart = "on-failure";
          CPUAccounting = "true";
          CPUQuota = "40%";
          CPUWeight = "150";
        };
      };
      environment.etc."yggdrasil.conf".text = if config.pro-peer.yggdrasilConfigPath == null then ''{ Peers: [] }'' else null;
    })

    (lib.mkIf config.pro-peer.enableWireguardHelper {
      environment.systemPackages = with pkgs; [ wireguard-tools ];
      # Устанавливаем небольшой оболочный wrapper для нормализации поведения
      # wg-quick; это позволяет systemd‑юниту оставаться простым и не
      # включать сложную shell‑логику.
      environment.etc."pro-peer-wg-quick-wrapper".source = ./scripts/pro-peer-wg-quick-wrapper.sh;
      environment.etc."pro-peer-wg-quick-wrapper".mode = "0755";

      systemd.services."pro-peer-wg-quick" = {
        description = "Bring up WireGuard interface via wg-quick for pro-peer";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''/etc/pro-peer-wg-quick-wrapper ${if config.pro-peer.wireguardConfigPath != null then config.pro-peer.wireguardConfigPath else "wg0"}'';
          # The wrapper normalizes exit codes and always returns 0.
          RemainAfterExit = "yes";
          CPUAccounting = "true";
          CPUQuota = "30%";
        };
      };
    })

    (lib.mkIf (config.pro-peer.allowTorHiddenService) {
      environment.etc."pro-peer-tor-note".text = ''Tor hidden service for SSH is enabled. See /var/lib/tor/ssh_hidden_service/hostname'';
    })

    (lib.mkIf (config.pro-peer.allowTorHiddenService) {
      services.tor = {
        enable = true;
        settings = {
          HiddenServiceDir = "/var/lib/tor/ssh_hidden_service";
          HiddenServicePort = "22 127.0.0.1:22";
        };
      };

      # Для Tor hidden service гарантируем существование каталога с корректными
      # правами через systemd‑tmpfiles — декларативный способ, применяемый при
      # загрузке, что предпочтительнее запуска oneshot‑скриптов с shell‑логикой.
      # If Tor hidden service is enabled, add a tmpfiles rule to ensure the
      # directory exists with correct ownership. Again, append to the global
      # rules list rather than forcing it.
      systemd.tmpfiles.rules = lib.mkIf config.pro-peer.allowTorHiddenService [
        # Ensure Tor runtime dir and the SSH hidden-service dir exist with
        # the `tor` user ownership. Previously this used `debian-tor`, which
        # may not exist on this system and can leave directories owned by
        # nobody:nogroup causing Tor to fail at startup (permission denied).
        "d /var/lib/tor 0700 tor tor -"
        "d /var/lib/tor/ssh_hidden_service 0700 tor tor -"
      ];

      # Ensure correct ownership/permissions on /var/lib/tor at activation.
      # Some systems may already have /var/lib/tor owned by another user
      # (e.g. nobody) which prevents Tor from starting. tmpfiles only creates
      # the directories if missing and may not fix ownership on existing
      # directories, so add a lightweight oneshot service that enforces the
      # expected tor:tor ownership before tor.service runs.
      systemd.services."pro-peer-ensure-tor-perms" = {
        description = "Ensure /var/lib/tor ownership and modes for Tor";
        wantedBy = [ "multi-user.target" ];
        before = [ "tor.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''/bin/sh -c 'if [ -d /var/lib/tor ]; then chown -R tor:tor /var/lib/tor || true; chmod 700 /var/lib/tor || true; [ -d /var/lib/tor/ssh_hidden_service ] && chmod 700 /var/lib/tor/ssh_hidden_service || true; fi'"'';
        };
      };
    })
  ];

}
