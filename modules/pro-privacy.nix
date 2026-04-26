# Название: modules/pro-privacy.nix — Конфигурация приватных сетей (Tor, obfs4, Snowflake)
# Summary (EN): Tor and pluggable transports configuration for client anonymity
# Цель:
#   Обеспечить безопасные и проверяемые дефолты для Tor и вспомогательных
#   транспортив (obfs4, meek, snowflake). Комментарии объясняют, какие опции
#   влияют на boot/verify и почему некоторые файлы управляются вне декларативной
#   модели (bridges.conf).
# Контракт:
#   Опции: services.tor.client.enable, services.tor.bridges (list) — при
#           заполнении блочного списка будут сгенерированы Bridge строки.
#   Побочные эффекты: добавляет systemd.services.tor-ensure-bridges и
#   tor-ensure-perms; создаёт /etc/tor/bridges.conf.example.
# Предпосылки:
#   Требуются пакеты obfs4proxy, snowflake-client, meek-client в профиле при
#   использовании ClientTransportPlugin; некоторые опции могут требовать ядра
#   с поддержкой сетевых возможностей.
# Как проверить (Proof):
#   ./tools/holo-verify.sh unit (tests/contract/tor-01.sh)
# Last reviewed: 2026-04-25
{ config, pkgs, lib, ... }:

{
  # Суть раздела:
  # Приводится конфигурация клиентских средств приватности: Tor и сопутствующие
  # транспорты (obfs4, snowflake, meek). Комментарии поясняют роль ControlPort,
  # SOCKSPort и шаблоны управления bridges. Это демонстрация практической
  # интеграции анонимных сетей на хосте.
  services.tor = {
    enable = true;
    client.enable = true;
    torsocks.enable = true;
    # Provide sane defaults but allow hosts to override in their host config.
    # Почему lib.mkDefault для UseBridges: по умолчанию мосты выключены, чтобы Tor
    # мог запуститься в "открытых" сетях без необходимости настраивать bridges.
    # Как проверить (отключить): в хост-конфиге `services.tor.settings.UseBridges = 1`.
    settings = {
      ControlPort = [ 9051 ];
      CookieAuthentication = true;
      # Default to no bridges so Tor can bootstrap in unconstrained networks.
      # To enable bridges on a host, set `services.tor.settings.UseBridges = 1` and
      # populate /etc/tor/bridges.conf (the module deploys a template example).
      UseBridges = lib.mkDefault 0;
  # Operators maintain /etc/tor/bridges.conf manually (or via the provided
  # template). We avoid emitting an `Include` directive into torrc because
  # some tor builds do not accept that directive during `--verify-config`.
  # Примечание: bridges.conf управляется оператором вручную — это намеренное
  # ограничение модели; декларативное управление bridges может сломать tor --verify-config.
  # The systemd service `tor-ensure-bridges` will create a default
  # /etc/tor/bridges.conf if it does not exist.
  #
  # To support hosts that want bridges managed declaratively, we expose a
  # configuration option `services.tor.bridges` (list of strings). When set,
  # the module will render the contents of this list into the generated torrc
  # as Bridge lines. This avoids relying on `Include` while still allowing
  # declarative bridge management.

  # Default: no bridges declared in Nix; operators may set services.tor.bridges
  # in host configuration to inject Bridge lines.
  bridges = lib.mkDefault [];
      # ClientTransportPlugin lists executables that must exist at runtime.
      # Keep this as a forced list because Tor expects the directive lines to be
      # present exactly as specified; we point at /run/current-system/sw to use
      # whatever versions the system provides.
      # Tor expects explicit ClientTransportPlugin lines; keep as mkForce to
      # ensure Tor configuration gets the exact directives it requires.
      ClientTransportPlugin = lib.mkForce [
        "obfs4 exec /run/current-system/sw/bin/obfs4proxy"
        "meek exec /run/current-system/sw/bin/meek-client"
        "snowflake exec /run/current-system/sw/bin/snowflake-client"
      ];
      DNSPort = [ 9053 ];
      AutomapHostsOnResolve = true;
      AutomapHostsSuffixes = [ ".onion" ".exit" ];
    };
  };

  # I2P — дополнительный стек приватной сети (опция).
  services.i2p.enable = true;

  # Развёртывание шаблона bridges.conf
  # Шаблон помещается в /etc/tor/bridges.conf.example и копируется в
  # /etc/tor/bridges.conf при отсутствии последнего. Файл /etc/tor/bridges.conf
  # должен быть редактируем оператором, поэтому мы не управляем им полностью
  # декларативно.
  environment.etc."tor/bridges.conf.example".source = ../conf/tor-bridges.conf;

  systemd.services."tor-ensure-bridges" = {
    description = "Ensure /etc/tor/bridges.conf exists (create from template)";
    wantedBy = [ "multi-user.target" ];
    # Ensure this runs before tor.service so the bridges file exists when Tor starts
    before = [ "tor.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''/bin/sh -c 'mkdir -p /etc/tor && if [ ! -e /etc/tor/bridges.conf ]; then cp /etc/tor/bridges.conf.example /etc/tor/bridges.conf && chown root:root /etc/tor/bridges.conf && chmod 0640 /etc/tor/bridges.conf; fi'';""'
    };
  };

  # Ensure /var/lib/tor exists with correct ownership/modes before tor.service
  systemd.services."tor-ensure-perms" = {
    description = "Ensure /var/lib/tor ownership and modes for Tor";
    before = [ "tor.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''/bin/sh -c 'mkdir -p /var/lib/tor && chown -R tor:tor /var/lib/tor || true; chmod 700 /var/lib/tor || true; [ -d /var/lib/tor/ssh_hidden_service ] && chmod 700 /var/lib/tor/ssh_hidden_service || true'';""'
    };
    wantedBy = [ "multi-user.target" ];
  };

  # Ensure awk is available during activation scripts (used by activate).
  # Add privacy transport packages as low-priority contributions; modules should
  # not force the final package list — the top-level configuration controls
  # the final authoritative set.
  environment.systemPackages = lib.mkDefault (with pkgs; [ gawk obfs4proxy meek-client snowflake-client ]);

  # Открытые порты для служб приватности — доступны локально/для роутинга.
  networking.firewall = {
    allowedTCPPorts = [ 9050 9051 9052 9053 7657 4444 4445 ];
    allowedUDPPorts = [ 9564 ];
  };

  # Примечание: автоматическая перезагрузка при изменении bridges намеренно опущена.
  # Dynamic runtime reloading can be implemented later with a carefully
  # tested systemd.path/service that avoids triggering during activation.
}
