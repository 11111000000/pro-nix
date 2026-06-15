# Название: modules/pro-ssh-clients.nix — генерация ssh_config.d для pro-nix
# Кратко: на основе реестра `pro.hosts` создаёт /etc/ssh/ssh_config.d/pro.conf
# с Host-блоками для каждого известного хоста, плюс глобальные настройки
# (HashKnownHosts, ServerAliveInterval). Цель — дать пользователю
# `ssh <shortname>` без отдельного DNS-сервера.
#
# Цель:
#   Удобный CLI: `ssh desktop`, `ssh cf19`, `ssh huawei` работают,
#   если доступен хотя бы один сетевой путь. Для каждого хоста модуль
#   генерирует primary `Host <name>` (с HostName = highest-priority
#   candidate, обычно tailnet FQDN) и secondary `Host <candidate>` для
#   остальных кандидатов, чтобы можно было форсировать маршрут явно:
#     ssh <name>             # primary (auto-route, обычно tailnet FQDN)
#     ssh <name>.local       # mDNS / LAN
#     ssh <name>-onion       # tor (если h.onion задан)
#   Порядок кандидатов: tailnet-FQDN → tailnet-short → mDNS `.local`
#   → fallback IP (h.addr). .onion обрабатывается отдельным блоком
#   (см. renderOnionHost). OpenSSH не умеет «first reachable wins»
#   нативно, поэтому failover'а между кандидатами нет — пользователь
#   сам выбирает алиас под текущую сеть.
#
# Контракт:
#   Опции:
#     pro.sshClient.enable — bool, по умолчанию true;
#     pro.sshClient.identityFile — путь к ключу (по умолчанию 11111000000_at_email_dot_com, общий с github.com/gitverse.ru);
#     pro.sshClient.connectTimeout — seconds for each Host block.
#   Побочные эффекты: пишет /etc/ssh/ssh_config.d/pro.conf (text).
#
# Как проверить (Proof):
#   nix build .#nixosConfigurations.<h>.config.system.build.toplevel
#   grep -A12 '^Host desktop$' /etc/ssh/ssh_config.d/pro.conf
#   ssh -G desktop | grep -E '^(hostname|user|identityfile)'
{ config, lib, pkgs, ... }:

let
  inherit (lib) concatStringsSep mapAttrsToList optional optionals
            findFirst foldl' filter elem optionalString;

  cfg = config.pro.sshClient;
  hosts = config.pro.hosts or {};

  tailnetDomain = "pro-nix.ts.net";

  # Build the candidate list in priority order, deduplicated. The
  # first entry is the most-preferred path (typically tailnet FQDN);
  # the rest become explicit aliases the user can pick via
  # `ssh <candidate>`. Onion is intentionally excluded here — it's
  # handled by `renderOnionHost` (which sets up torsocks ProxyCommand)
  # under the `<name>-onion` alias.
  buildCandidates = name: h:
    let
      raw = [
        "${h.tailnet}.${tailnetDomain}"
        h.tailnet
        "${name}.local"
      ] ++ optional (h.addr != null) h.addr;
    in
      foldl' (acc: c: if elem c acc then acc else acc ++ [c]) [] raw;

  # Render one `Host` block for a given host. `alias` is the pattern
  # OpenSSH matches against user input; `hostName` is what OpenSSH
  # connects to. If `hostName` is null (degenerate case where every
  # candidate equals the alias itself), the block has no `HostName`
  # and OpenSSH uses the literal input as hostname.
  renderBlock = name: h: alias: hostName: ''
    # pro-nix managed block: ${name}
    Host ${alias}
        User ${h.sshUser}
        Port 22
        ${optionalString (hostName != null) "HostName ${hostName}"}
        IdentityFile ${cfg.identityFile}
        IdentitiesOnly yes
        PreferredAuthentications publickey
        StrictHostKeyChecking accept-new
        HashKnownHosts yes
        UpdateHostKeys yes
        ServerAliveInterval 30
        ServerAliveCountMax 3
        ConnectTimeout ${toString cfg.connectTimeout}
  '';

  # For each host, render a primary `Host <name>` (HostName = first
  # candidate that differs from the alias itself) and one explicit
  # alias per remaining candidate. This makes `ssh <name>` route via
  # a concrete hostname (typically the tailnet FQDN) even though the
  # bare `<name>` doesn't resolve in DNS or mDNS, and lets the user
  # force a specific network with `ssh <candidate>` (e.g. `ssh
  # desktop.local` to use mDNS when the tailnet is down).
  renderHost = name: h:
    let
      candidates = buildCandidates name h;
      primaryHostName = findFirst (c: c != name) null candidates;
      secondary = filter (c: c != primaryHostName && c != name) candidates;
    in
      concatStringsSep "\n"
        ([ (renderBlock name h name primaryHostName) ]
         ++ map (c: renderBlock name h c c) secondary);

  # If a host has an onion name, add a dedicated block that uses torsocks
  # as a ProxyCommand. The match only triggers when the user types
  # `ssh <name>-onion` (suffix) to keep default `ssh <name>` snappy.
  renderOnionHost = name: h: optional (h.onion != null) ''
    # pro-nix tor fallback for ${name}
    Host ${name}-onion
        User ${h.sshUser}
        HostName ${h.onion}
        Port 22
        IdentityFile ${cfg.identityFile}
        IdentitiesOnly yes
        PreferredAuthentications publickey
        StrictHostKeyChecking accept-new
        ProxyCommand ${pkgs.torsocks}/bin/torsocks ${pkgs.openssh}/bin/ssh -W %h:%p
        ConnectTimeout 30
  '';

  body = let
    hasHosts = (builtins.length (builtins.attrNames hosts)) > 0;
    # Render every host block. We collect per-host lines first, then join
    # — note that `mapAttrsToList (n: h: ...)` returns a list of strings
    # (each rendered Host block is one string), so a single concat is enough.
    hostBlocks = mapAttrsToList renderHost hosts
      ++ mapAttrsToList
        (n: h: concatStringsSep "\n" (renderOnionHost n h))
        hosts;
    bodyText = ''
      # pro-nix managed ssh_config (do not edit by hand — regenerated by nixos-rebuild).
      # For each known host (see modules/pro-hosts.nix) the module emits a
      # primary `Host <name>` block plus one explicit `Host <candidate>`
      # block per remaining candidate (see head of this file for the
      # priority order). Pick the alias that matches your current network.
      Host *
          HashKnownHosts yes
          CanonicalizeHostname no
          ServerAliveInterval 30
          ServerAliveCountMax 3
          ConnectTimeout ${toString cfg.connectTimeout}

    '' + concatStringsSep "\n" hostBlocks;
  in if cfg.enable && hasHosts then bodyText else "";
in

{
  options.pro.sshClient = {
    enable = lib.mkEnableOption "Generate /etc/ssh/ssh_config.d/pro.conf from pro.hosts" // { default = true; };
    identityFile = lib.mkOption {
      type = lib.types.str;
      # 11111000000_at_email_dot_com — общий SSH-ключ пользователя
      # (тот же, что уже закреплён за github.com и gitverse.ru в
      # ~/.ssh/config). Держим единый ключ для кластера, чтобы избежать
      # рассинхрона: раньше default был id_ed25519, но authorized_keys на
      # desktop был пустой для него, и `ssh desktop.local` падал.
      default = "~/.ssh/11111000000_at_email_dot_com";
      description = "Default identity file used in generated Host blocks.";
    };
    connectTimeout = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Per-candidate HostName ConnectTimeout in seconds.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Render the file. Putting it in /etc/ssh/ssh_config.d/ means it will
    # be picked up by openssh automatically (ssh_config.d is included by
    # default since OpenSSH 7.3 and NixOS enables it).
    environment.etc."ssh/ssh_config.d/pro.conf".text = body;
  };
}
