# Название: modules/pro-hosts.nix — Каталог хостов pro-nix (single source of truth)
# Кратко: определяет декларативный реестр известных хостов кластера и их
# свойств (роль, sshUser, tailnet name, onion, fallback addr). Используется
# всеми сетевыми модулями (pro-ssh-clients, pro-network, pro-tailnet,
# host-policies) для согласованной генерации ssh_config.d, ACL и firewall.
#
# Цель:
#   Заменить разрозненные места описания хостов одним общим набором опций.
#   Декларация `pro.hosts.<name>` в этом модуле (или в `configuration.nix`)
#   служит источником правды для: SSH-алиасов, DNS, ACL, headscale-groups,
#   tailscale-тегов, fail2ban-jails.
#
# Контракт:
#   Опции:
#     config.pro.hosts.<name> = {
#       sshUser   = "<unix user для SSH-логина>";
#       roles     = [ "laptop" "server" "lan-gw" "tor" "headscale" ];
#       tailnet   = "<shortname в tailnet, по умолчанию = name>";
#       onion     = "<v3 hidden service hostname, опционально>";
#       addr      = "<статический IP вне mesh, опционально>";
#       tags      = [ "<tailscale ACL tags>" ];
#     };
#   Побочные эффекты: только декларативный список; генерацию ssh_config
#   делает pro-ssh-clients.nix, mesh-интеграцию — pro-tailnet.nix.
#
# Как проверить (Proof):
#   nix eval --json .#nixosConfigurations.<h>.config.pro.hosts --apply builtins.attrNames
#   rg "pro\\.hosts\\." modules tests
{ config, lib, ... }:

let
  inherit (lib) mkOption mkEnableOption types;

  hostType = types.submodule {
    options = {
      sshUser = mkOption {
        type = types.str;
        default = "az";
        description = "SSH login user for this host.";
      };
      roles = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ "laptop" "server" ];
        description = ''
          Role tags used for ACLs, ACL groups, and SSH rule emission.
          Conventional values: laptop, server, lan-gw, headscale, tor, backup.
        '';
      };
      tailnet = mkOption {
        type = types.str;
        description = "Short hostname inside the tailnet (defaults to attribute name).";
      };
      onion = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional Tor v3 onion address (used as ultimate fallback).";
      };
      addr = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Optional non-mesh address (e.g. a public DNS A record or LAN IP).
          Only used as last-resort SSH fallback.
        '';
      };
      tags = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Tailscale ACL tags, applied to the host's machine key.";
      };
    };
  };

  # Default registry: known hosts in this pro-nix cluster. Hosts that need
  # local-only secrets (e.g. onion address) may override entries in
  # `local.nix`. Do NOT delete entries when a host goes offline — keep
  # the registry stable so the rest of the cluster can keep referencing
  # them by name even when the host is temporarily down.
  defaultHosts = {
    station = {
      sshUser = "az";
      roles = [ "server" "headscale" "lan-gw" "nfs" "tor" ];
      tailnet = "station";
    };
    cf19 = {
      sshUser = "az";
      roles = [ "laptop" "tor" ];
      tailnet = "cf19";
    };
    huawei = {
      sshUser = "az";
      roles = [ "laptop" "tor" ];
      tailnet = "huawei";
    };
    vm = {
      sshUser = "az";
      roles = [ "vm" "lab" ];
      tailnet = "vm";
    };
  };
in

{
  options.pro.hosts = mkOption {
    type = types.attrsOf hostType;
    default = {};
    description = ''
      Declarative catalog of pro-nix hosts. Module is purely declarative
      and produces no runtime side effects of its own; consumers
      (pro-ssh-clients, pro-tailnet, pro-network) read this attribute set.
    '';
  };

  # Provide default values. Use `default` so the user can override entries
  # by setting `pro.hosts.<name> = { ... }` in local.nix with `lib.mkForce`
  # if they really want to fully replace the entry.
  config.pro.hosts = defaultHosts;
}
