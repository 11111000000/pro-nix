# Название: modules/pro-peer.nix — Обнаружение пиров и управление ключами SSH
# Summary (EN): Peer discovery (Avahi), SSH hardening and authorized_keys sync
/* RU: Модуль обнаружения пиров: Avahi, жёсткая настройка SSH и синхронизация authorized_keys.
   Файл обязан содержать шапку контракта (назначение, контракт опций, побочные эффекты, Proof).
*/
# Цель:
#   Включает службы обнаружения в LAN (mDNS/Avahi), устанавливает безопасные
#   дефолты для SSH и обеспечивает механизм синхронизации authorized_keys из
#   зашифрованного файла при необходимости.
# Контракт:
#   Опции: config.pro-peer.enable — включение модуля;
#           config.pro-peer.enableKeySync — включить systemd-сервис синхронизации ключей;
#           config.pro-peer.keysGpgPath — путь к зашифрованному файлу ключей.
#   Побочные эффекты: создаёт tmpfiles правила для /var/lib/pro-peer и файла
#   /var/lib/pro-peer/authorized_keys; добавляет systemd.services.pro-peer-sync-keys
#   при enableKeySync; может включать tor.hidden service если allowTorHiddenService.
# Предпосылки:
#   Требуются пакеты: gnupg (при enableKeySync), avahi (для mDNS). Для Tor — tor.
# Как проверить (Proof):
#   ./tools/holo-verify.sh unit (tests/contract/pro-peer-01.sh)
# Last reviewed: 2026-04-25
{ config, pkgs, lib, ... }:

let
  cfg = {};

  # Helper scripts installed into the system profile to avoid complex inline
  # quoting in systemd unit ExecStart. This mirrors the pattern used in
  # modules/pro-privacy.nix: create small store-installed wrappers and reference
  # their absolute paths from unit files. Keeps units verifiable by
  # `systemd-analyze verify`.
  helpers = {
    proPeerSync = pkgs.writeShellScriptBin "pro-peer-sync" ''
      #!/usr/bin/env bash
      set -euo pipefail
      exec /run/current-system/sw/bin/bash /etc/pro-peer-sync-keys.sh --input ${config.pro-peer.keysGpgPath} --out /var/lib/pro-peer/authorized_keys
    '';

    proPeerBackupHidden = pkgs.writeShellScriptBin "pro-peer-backup-hiddenservice" ''
      #!/usr/bin/env bash
      set -euo pipefail
      exec /run/current-system/sw/bin/bash /etc/pro-peer-backup-hiddenservice.sh --hidden-dir /var/lib/tor/ssh_hidden_service --recipient ${config.pro-peer.torBackupRecipient} --out-dir /var/lib/pro-peer
    '';

    proPeerEnsureTorPerms = pkgs.writeShellScriptBin "pro-peer-ensure-tor-perms" ''
      #!/usr/bin/env bash
      set -euo pipefail
      if [ -d /var/lib/tor ]; then
        chown -R tor:tor /var/lib/tor || true
        chmod 700 /var/lib/tor || true
        [ -d /var/lib/tor/ssh_hidden_service ] && chmod 700 /var/lib/tor/ssh_hidden_service || true
      fi
    '';

    proPeerWgQuick = pkgs.writeShellScriptBin "pro-peer-wg-quick-wrapper" (''
      #!/usr/bin/env bash
      set -euo pipefail
      WG_PATH="${if config.pro-peer.wireguardConfigPath != null then config.pro-peer.wireguardConfigPath else "wg0"}"
      exec /run/current-system/sw/bin/bash /etc/pro-peer-wg-quick-wrapper "$WG_PATH"
    '');
  };

in

{
  options = {
    pro-peer = {
      enable = lib.mkEnableOption "Enable pro peer discovery defaults (Avahi + SSH hardening)";
      allowTorHiddenService = lib.mkEnableOption "Enable Tor hidden service for SSH (off by default)";
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
  # Раздел описывает механизмы обнаружения в локальной сети (mDNS/Avahi),
  # управление ключами SSH и интеграцию с альтернативными сетевыми слоями
  # (Tor, Yggdrasil, WireGuard). Комментарии показывают архитектуру взаимодействия
  # модулей и почему используется tmpfiles/systemd для создания runtime-путей.
  config = lib.mkMerge [
    (lib.mkIf config.pro-peer.enable {
      # Avahi — служба mDNS для обнаружения хостов в локальной сети (LAN).
      services.avahi = {
        enable = true;
        publish = {
          enable = true; # публиковать хост через mDNS
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

      # Почему tmpfiles: tmpfiles — декларативный способ, применяется systemd при загрузке,
      # idempотентен и не требует запуска oneshot-скриптов при каждом обновлении.
      # Почему не указываем путь в sshd module: sshd eval происходит до рантайма,
      # файл может быть недоступен — tmpfiles создаёт директорию к моменту старта sshd.
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
        # Почему lib.mkDefault: позволяет хостам переопределять порты без насильственного
        # перезаписывания; lib.mkForce бы сломал переопределения в других модулях.
        # Как проверить: добавить в хост `networking.firewall.allowedUDPPorts = []` — порт исчезнет.
        # Почему lib.concatLists:合并ваем с已有的, не теряя порты из других модулей.
        allowedUDPPorts = lib.mkDefault (lib.concatLists [ (config.networking.firewall.allowedUDPPorts or []) [ 5353 ] ]);
        # Дополнительно добавляем idempotent правила через extraCommands, чтобы
        # разрешить IPv4 и IPv6 multicast (224.0.0.251 и ff02::fb), используемые
        # Avahi для обнаружения в сети.
        # Add idempotent iptables rules as a default; allow hosts to override
        # by using lib.mkDefault instead of lib.mkForce.
        extraCommands = lib.mkDefault ''
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
      # Do not force root authorized keys to an empty set at module level;
      # make this additive/default so host configuration can provide keys.
      users.users.root.openssh.authorizedKeys = lib.mkDefault { keys = []; keyFiles = []; };
    })

    (lib.mkIf config.pro-peer.enableKeySync {
      # Make package contribution additive and low-priority so top-level
      # aggregation decides final list. Avoid lib.mkForce at module level.
      environment.systemPackages = lib.mkDefault (with pkgs; [ gnupg ]);
      environment.etc."pro-peer-sync-keys.sh".source = ../scripts/pro-peer-sync-keys.sh;
      environment.etc."pro-peer-sync-keys.sh".mode = "0755";
      # Expose a canary helper script for operators to run dry-run locally
      environment.etc."pro-peer-canary.sh".source = ../scripts/pro-peer-canary.sh;
      environment.etc."pro-peer-canary.sh".mode = "0755";

      systemd.services."pro-peer-sync-keys" = {
        description = "Pro‑peer: sync authorized_keys from encrypted file";
        wantedBy = [ "multi-user.target" ];
        # Ограничиваем CPU: oneshot-задача не должна блокировать интерактивные сессии.
        # Как проверить: `systemctl show pro-peer-sync-keys | grep CPUQuota`
        # CPUAccounting и CPUQuota — защитная мера, не функциональная зависимость.
        serviceConfig = {
          Type = "oneshot";
          # Use absolute path to bash from the current system profile so the
          # unit does not depend on PATH during activation. This makes the
          # unit reproducible and avoids errors like "env: 'bash': No such
          # file or directory" during `nixos-rebuild switch`.
          ExecStart = "${helpers.proPeerSync}/bin/pro-peer-sync";
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
      environment.systemPackages = lib.mkDefault (with pkgs; [ gnupg tar ]);
      environment.etc."pro-peer-backup-hiddenservice.sh".source = ../scripts/backup-hiddenservice.sh;
      environment.etc."pro-peer-backup-hiddenservice.sh".mode = "0755";

      systemd.services."pro-peer-backup-hiddenservice" = {
        description = "Backup tor hidden service key encrypted to recipient";
        after = [ "tor.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${helpers.proPeerBackupHidden}/bin/pro-peer-backup-hiddenservice";
          CPUQuota = "30%";
        };
      };
    })

    (lib.mkIf config.pro-peer.enableYggdrasil {
      environment.systemPackages = lib.mkDefault (with pkgs; [ yggdrasil ]);
      systemd.services.yggdrasil = {
        description = "Yggdrasil mesh daemon (pro-peer)";
        wantedBy = [ "multi-user.target" ];
        # Даём демону mesh небольшую долю CPU и защищаем систему от его
        # перегрузки при интенсивной сетевой активности.
        serviceConfig = {
          ExecStart = builtins.concatStringsSep " " [ (builtins.toString pkgs.yggdrasil + "/bin/yggdrasil") "-useconffile" (if config.pro-peer.yggdrasilConfigPath != null then config.pro-peer.yggdrasilConfigPath else "/etc/yggdrasil.conf") ];
          Restart = "on-failure";
          CPUQuota = "40%";
          CPUWeight = "150";
        };
      };
      environment.etc."yggdrasil.conf".text = if config.pro-peer.yggdrasilConfigPath == null then ''{ Peers: [] }'' else null;
    })

    (lib.mkIf config.pro-peer.enableWireguardHelper {
      environment.systemPackages = lib.mkDefault (with pkgs; [ wireguard-tools ]);
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
          ExecStart = "${helpers.proPeerWgQuick}/bin/pro-peer-wg-quick-wrapper";
          # The wrapper normalizes exit codes and always returns 0.
          RemainAfterExit = "yes";
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

      # Почему tmpfiles вместо oneshot: tmpfiles применяется при загрузке, декларативный
      # способ, более надёжен; oneshot может не сработать при перезагрузке.
      # Как проверить: `ls -la /var/lib/tor/ssh_hidden_service` после перезагрузки.
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
          ExecStart = "${helpers.proPeerEnsureTorPerms}/bin/pro-peer-ensure-tor-perms";
        };
      };
    })
  ];

}
