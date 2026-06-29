+++
title = "Privacy &amp; Tor"
template = "page.html"
weight = 5

[extra]
tldr = "Tor + obfs4 + meek + snowflake, onionshare, dnscrypt-proxy, mullvad-vpn, wireguard-tools, yggdrasil mesh. SOCKS5 on 9050, DNS on 9053, control on 9051. pro-tor CLI toggles per-shell."

[[extra.next]]
title = "Dev tooling"
url = "/stack/dev/"

[[extra.next]]
title = "Network layers"
url = "/architecture/network/"
+++

# Privacy &amp; Tor

The project treats **anonymity and censorship-resistance** as first-class
infrastructure. A user on a hotel Wi-Fi, a journalist under regime
pressure, or a developer behind a corporate proxy can route any command
through Tor with one shell command.

## The Tor stack

`modules/pro-privacy.nix` activates:

* `services.tor.enable = true` (set at the top level in
  `configuration.nix:138-147`; pro-privacy adds the pluggable transports).
* `services.tor.client.enable = true`.
* `services.torsocks.enable = true` — the LD_PRELOAD shim.
* `ClientTransportPlugin`:
  * `obfs4 exec ${pkgs.obfs4}/bin/lyrebird`
  * `meek exec ${pkgs.meek}/bin/meek-client`
  * `snowflake exec ${pkgs.snowflake}/bin/snowflake-client`
* `ControlPort 9051` (cookie auth).
* `DNSPort 9053` with `AutomapHostsOnResolve = true` and
  `AutomapHostsSuffixes = ".onion", ".exit"`.
* `services.i2p.enable = lib.mkDefault false` (off by default).

The bridges are managed by `host-policies.nix` (host-specific) and
the `conf/tor-bridges.conf` example. `huawei` has snowflake enabled
by default; `cf19` opts into the Tor hidden service for SSH.

## The `pro-tor` CLI

`scripts/pro-tor` (~400 lines, bash) is the user-facing Tor toggle. Two
modes:

```bash
pro-tor local on|off|status|detect        # local tor.service, 127.0.0.1:9050
pro-tor remote on|off|status|detect       # Orbot on Android AP, scanned /24
pro-tor detect [--mode local|remote]      # find a proxy, no enabling
pro-tor verify [HOST[:PORT]]              # confirm it's a real Tor exit
pro-tor env                               # print export lines (for eval)
```

### How it detects a remote proxy

The default candidate set:

1. Default gateway (from `ip -4 route show default`).
2. `<gw%.*.*>.1.1` (if the gateway is in a `*.1.*` pattern).
3. `192.168.43.1` (Android AP default).
4. `192.168.49.1` (USB-tethering default).
5. With `--scan-subnet`: every address in the gateway's /24.

For each candidate, `nc -z -w 1` (or `bash /dev/tcp/...` as fallback)
checks TCP 9050, then `curl --socks5-hostname $host:9050
https://check.torproject.org/ | grep "Congratulations"` verifies it's a
real Tor exit (skippable with `--no-verify`).

### What it does on `on`

`do_on` writes `~/.config/pro-tor/env` (mode 0700 dir, 0600 file) with:

```bash
export ALL_PROXY="socks5h://host:port"
export all_proxy="socks5h://host:port"
export HTTP_PROXY="http://host:port"
export HTTPS_PROXY="http://host:port"
export NO_PROXY="127.0.0.1,localhost,*.local,.local,::1"
export PRO_TOR_MODE="local"   # or "remote"
export PRO_TOR_TARGET="host:port"
export PRO_TOR_ENABLED=1
```

Apply in the current shell with `source ~/.config/pro-tor/env` or
`eval "$(pro-tor env)"`.

## `bin/torwrap`

`bin/torwrap` is a thin wrapper for "run this command through Tor":

1. Find `pro-tor` in PATH or in known Nix profile paths.
2. `pro-tor detect --no-verify --mode local` (then `--mode remote`).
3. If a proxy is found, `exec` through `torsocks` → `proxychains4` →
   raw `ALL_PROXY=...`.

Exit codes:

* `3` — `pro-tor` not found.
* `4` — no Tor proxy detected.
* `5` — bad `host:port` format.

## Onion services

`modules/pro-peer.nix` (when `pro-peer.allowTorHiddenService = true`)
sets up an SSH onion service:

* `services.tor.hiddenService."ssh" = { port = 22; target = "127.0.0.1:22"; }`.
* `pro-peer.torBackupRecipient` (GPG key id) is used by
  `ops-backup-hiddenservice.sh` to encrypt the hidden service dir to
  `/var/lib/pro-peer/hidden-service.gpg`.
* The generated `ssh_config.d/pro.conf` has a separate
  `Host <name>-onion` block that uses torsocks as a `ProxyCommand`.

The onion name is registered in `pro.hosts.<name>.onion` and survives a
host reboot.

## Yggdrasil and WireGuard

`modules/pro-peer.nix` has two opt-in features (off by default):

* `pro-peer.enableYggdrasil` — runs `yggdrasil` with
  `pro-peer.yggdrasilConfigPath` (default `/etc/yggdrasil.conf`).
* `pro-peer.enableWireguardHelper` — installs a `wg-quick` wrapper
  (`pro-peer-wg-quick-wrapper`) that ignores the "already up" exit
  code. Uses `pro-peer.wireguardConfigPath` (default `wg0`).

These are mesh / overlay network fallbacks for when neither LAN-mDNS nor
headscale reaches a host.

## The firewall

`pro-privacy.nix` opens:

* `9050/tcp` — SOCKS5.
* `9051/tcp` — Control.
* `9052/tcp` — fetch.
* `9053/udp` — DNS.
* `7657/tcp` — I2P console.
* `4444/tcp`, `4445/tcp` — I2P services.
* `9564/udp` — mDNS helper (not used by pro-nix).

By default these are **LAN-only** (RFC1918 sources) through the
host-policy iptables rules in `host-policies.nix`.

## Other privacy tools in the closure

| Package | Purpose |
|---------|---------|
| `dnscrypt-proxy` | Encrypted DNS to Cloudflare/Quad9. |
| `onionshare` | Anonymous file sharing over Tor. |
| `nyx` | Tor relay monitor (TTY). |
| `proxychains` | Alternative to torsocks for non-LD_PRELOAD scenarios. |
| `mullvad-vpn` | Commercial VPN client (no account required). |
| `wireguard-tools` | `wg`, `wg-quick`. |
| `i2p` | I2P router (off by default). |

These are in the **privacy** composition file
(`system-package-sets-privacy.nix`) and are installed on `huawei` and
`vm` by default.

## What is **not** in the stack

* `services.tailscale.enable = true` — would require an auth key, which
  breaks `nixos-rebuild` without a secret. The headscale role gives
  Tailscale-equivalent mesh without the auth-key requirement.
* `i2p` — enabled on demand only.
* `mullvad-vpn` account — the binary is installed, the user enters
  their account on first use.
