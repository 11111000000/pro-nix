{ config, lib, pkgs, ... }:

let
  isHuawei = config.networking.hostName == "huawei";
  isCf19 = config.networking.hostName == "cf19";
in
{
  config = lib.mkMerge [
    {
      services.tor = lib.mkDefault {
        enable = true;
        client.enable = true;
        torsocks.enable = true;
        settings = {
          ControlPort = [ 9051 ];
          CookieAuthentication = true;
          DNSPort = [ 9053 ];
          AutomapHostsOnResolve = true;
          AutomapHostsSuffixes = [ ".onion" ".exit" ];
        };
      };

      networking.firewall.allowedTCPPorts = lib.mkDefault [ 9050 9051 9053 22 ];
      networking.firewall.allowedUDPPorts = lib.mkDefault [ 9564 ];
      networking.firewall.extraCommands = lib.mkAfter ''
        # Allow SSH only from RFC1918 ranges and loopback.
        iptables -C INPUT -p tcp -s 10.0.0.0/8 --dport 22 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp -s 10.0.0.0/8 --dport 22 -j ACCEPT || true
        iptables -C INPUT -p tcp -s 172.16.0.0/12 --dport 22 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp -s 172.16.0.0/12 --dport 22 -j ACCEPT || true
        iptables -C INPUT -p tcp -s 192.168.0.0/16 --dport 22 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 22 -j ACCEPT || true
        iptables -C INPUT -p tcp -s 127.0.0.0/8 --dport 22 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp -s 127.0.0.0/8 --dport 22 -j ACCEPT || true
        iptables -C INPUT -p tcp --dport 22 -j DROP 2>/dev/null || iptables -A INPUT -p tcp --dport 22 -j DROP || true
      '';

      services.openssh = {
        enable = true;
        settings = {
          PermitEmptyPasswords = "no";
          MaxAuthTries = 3;
          X11Forwarding = false;
          AllowTcpForwarding = false;
        };
      };
    }

    (lib.mkIf isHuawei {
      systemd.services."dbus-org.freedesktop.nm-dispatcher" = {
        description = "DBus hand-off unit for NetworkManager dispatcher";
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.networkmanager}/libexec/nm-dispatcher";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      services.tor.settings = {
        Bridge = [
          "obfs4 176.123.7.245:1790 C4A4913604C2DAE506A5B2E873EC94651B8F91D4 cert=R4PMGkCgTupeG8TOO9aKCMbZPA38bapGIjIUYlR3jOV9d41QJdpSlsdpx/gA1YVRpCO2LA iat-mode=0"
          "obfs4 152.53.184.244:4433 1B180961057F12C8D11943C566A388E14FD53E56 cert=y6AiE71HA32cRzDTtJ6weIEadN4e3SPmcVbGXIne549cKHRdBw5Q1DU/ZoPAy2CXcYg8LA iat-mode=0"
        ];
        UseBridges = 1;
      };
      services.tor.enableSnowflake = true;
    })

    (lib.mkIf isCf19 {
      pro-peer.allowTorHiddenService = true;

      # CF-19: жёсткая политика стабильности WiFi на iwlwifi/iwlmvm.
      # Цель — не дать чипу «уснуть» и потерять BSS, особенно при
      # подключении к Android-hotspot (см. docs/analyse/2026-06-02-network-drops-cf19.md).
      #
      # Каждая опция задокументирована: что делает и почему именно так.
      # boot.extraModprobeConfig собирается через lib.mkAfter, чтобы не
      # конфликтовать с другими модулями (например, btusb в desktop/...).
      boot.extraModprobeConfig = lib.mkAfter ''
        # iwlwifi: выключить firmware power-save. Без этого чип периодически
        # засыпает между beacon'ами и теряет sync, особенно в режиме
        # клиента точки доступа с плохим SNR.
        options iwlwifi power_save=0
        # iwlmvm: режим производительности (1 = performance). Понижает
        # задержку пробуждения радио и уменьшает вероятность roam-петли.
        options iwlmvm power_scheme=1
        # 11n_disable=0 — оставить 802.11n включённым, но 11n_ht40=0
        # запрещает 40-МГц каналы: на 2.4 ГГц они дают помехи и рост
        # retry-rate в плотной застройке.
        options cfg80211 ieee80211_default_rc_algo=minstrel_ht
        options iwlwifi 11n_disable=8
        options iwlmvm uapsd_disable=1
      '';
    })
  ];
}
