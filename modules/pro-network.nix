# Название: modules/pro-network.nix — общая сетевая база pro-nix
# Кратко: включает mDNS/Avahi (с NSS-интеграцией) и единый набор firewall
# дефолтов. Используется всеми хостами pro-nix, чтобы LAN-обнаружение
# было предсказуемым и резолв `host.local` работал без ручной правки
# nsswitch.conf.
#
# Цель:
#   Включить /etc/avahi/services/ssh.service (уже делает pro-peer) +
#   nss-mdns, чтобы `getent hosts desktop.local` отдавал LAN-IP. Дополнить
#   systemd-resolved: MulticastDNS=yes, когда он используется.
#   Это самый дешёвый способ обеспечить `ssh host.local` внутри одной сети.
#
# Контракт:
#   Опции:
#     pro.network.useMdns — bool (default true).
#     pro.network.allowSubnetRouter — bool (default false), включает IP
#       forwarding и NAT, нужно для хостов с ролью `lan-gw`.
#   Побочные эффекты: opens 5353/udp (если включён firewall), ставит пакет
#     `nss-mdns` в профиль, дописывает MulticastDNS в resolved extra.
#
# Как проверить (Proof):
#   `getent hosts desktop.local` — должен вернуть LAN-IP.
#   `avahi-browse -rt _ssh._tcp` — должен видеть соседей.
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption types;

  cfg = config.pro.network;
  isLanGw = builtins.elem "lan-gw" (config.pro.hosts.${config.networking.hostName}.roles or []);

in

{
  options.pro.network = {
    useMdns = mkEnableOption "Enable Avahi mDNS + NSS + resolved MulticastDNS" // { default = true; };
    allowSubnetRouter = mkOption {
      type = types.bool;
      default = isLanGw;
      description = ''
        Enable IPv4/v6 forwarding + masquerade, required for hosts that
        route traffic from the LAN to the tailnet. Auto-enabled when the
        host has the `lan-gw` role in pro.hosts.
      '';
    };
  };

  # Use mkMerge to combine two independent conditionals. The module-level
  # `config` attribute must appear exactly once, so we collect fragments
  # via lib.mkMerge below.
  config = lib.mkMerge [
    (lib.mkIf cfg.useMdns {
      # Avahi with NSS — nssmdns4/6 обязателен: без него Linux не будет
      # резолвить `foo.local` через glibc NSS, и `ssh foo.local` отвалится
      # по "Name or service not known".
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        nssmdns6 = true;
        publish = {
          enable = true;
        };
      };

      # nss-mdns в closure — для glibc NSS-плагина, без которого Avahi
      # рекламирует, но NSS не спрашивает.
      environment.systemPackages = with pkgs; [ nssmdns ];

      # Резолв через systemd-resolved, когда он включён: добавляем
      # MulticastDNS=yes в extraConfig. `services.resolved.extraConfig` — это
      # `separatedString` (sep = "\n"), так что несколько присваиваний склеиваются
      # через перевод строки. Используем lib.mkAfter, чтобы host-local override
      # (например, conf/resolved-extra.conf на desktop) имел приоритет выше,
      # а наши MulticastDNS-строки попадали в хвост — там, где их никто
      # не переопределит.
      # NB: LLMNR здесь намеренно НЕ задаём — `services.resolved.llmnr`
      # управляет тем же ключом через отдельный enum-тип. Хосты, где
      # LLMNR должен быть выключен, переопределяют опцию напрямую.
      services.resolved.extraConfig = lib.mkIf config.services.resolved.enable (lib.mkAfter ''
        [Resolve]
        MulticastDNS=yes
      '');

      # Firewall: 5353/udp для mDNS. lib.mkDefault — хосты могут отключить
      # порт при отсутствии LAN-сети.
      # NB: self-ref на config.networking.firewall.* запрещён (бесконечная
      # рекурсия в NixOS), поэтому используем lib.mkAfter с фиксированным
      # значением, которое NixOS-merge добавит к существующему списку.
      networking.firewall.allowedUDPPorts = [ 5353 ];
    })

    (lib.mkIf cfg.allowSubnetRouter {
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };
      # Добавляем tailscale0 в trusted-интерфейсы, чтобы пакеты от
      # tailnet-клиентов не подвергались фильтрации INPUT. lib.mkAfter —
      # чтобы наш trust-override наступил ПОСЛЕ host-local default.
      networking.firewall.trustedInterfaces = [ "tailscale0" ];
      # MASQUERADE: разрешаем хост-уровневый NAT через основной uplink.
      # lib.mkBefore — наш NAT-override ниже host-local extraCommands
      # (например, RFC1918-правил от modules/host-policies.nix), чтобы они
      # выполнялись раньше и не затирали наш MASQUERADE.
      networking.firewall.extraCommands = lib.mkBefore ''
        iptables -t nat -C POSTROUTING -o $(ip route show default | awk '{print $5; exit}') -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -o $(ip route show default | awk '{print $5; exit}') -j MASQUERADE || true
      '';
    })
  ];
}
