+++
title = "Per-host checklist"
template = "page.html"
weight = 8

[extra]
tldr = "After just switch, each host has a small list of post-install steps. desktop needs noise key backup + user creation; cf19 needs i8042 sanity + WiFi recovery; huawei needs SOF audio; vm needs sudo sanity."

[[extra.next]]
title = "Troubleshooting"
url = "/workflow/troubleshoot/"

[[extra.next]]
title = "Quick start"
url = "/workflow/quickstart/"
+++

# Per-host checklist

After `sudo just switch <host>`, each host has a small list of
post-install steps. The lists below assume the host was built with
the default `local.nix` (no secrets, no overrides).

## desktop

```bash
# 1. SSH keys
ssh-copy-id -i ~/.ssh/id_ed25519.pub az@desktop.local

# 2. Avahi (mDNS for LAN SSH discovery)
systemctl status avahi-daemon
avahi-browse -rt _ssh._tcp | grep desktop
getent hosts desktop.local
getent hosts cf19.local        # if cf19 is online

# 3. NFS export setup
install -d -m 2775 -o root -g pro /srv/nfs
exportfs -v | grep /srv/nfs

# 4. Headscale — back up the noise key ONCE
sudo cp /var/lib/headscale/noise_private.key /etc/headscale/
sudo chmod 0600 /etc/headscale/noise_private.key
# Pin via local.nix:
#   headscale.settings.noise.private_key = "<base64>";

# 5. Headscale user + preauthkey
sudo headscale users create az
sudo headscale preauthkeys create --user az --reusable --expiration 24h
# Save the preauthkey — paste into the client host's just switch.

# 6. Headscale listens on 0.0.0.0:8080 (LAN only by default)
#    If accepting registrations from WAN, add to local.nix:
#      networking.firewall.allowedTCPPorts = [ 8080 ];

# 7. Tor (if you want the onion hostname for SSH)
sudo systemctl status tor
#    /var/lib/tor/ssh_hidden_service/hostname is the onion.
#    Register it in pro.hosts.desktop.onion via local.nix.

# 8. zram
systemctl status zram.slice

# 9. LAN gateway
sysctl net.ipv4.ip_forward        # should be 1
ip route show default
```

## cf19

```bash
# 1. SSH keys
ssh-copy-id -i ~/.ssh/id_ed25519.pub az@cf19.local

# 2. BIOS-mode sanity
cat /proc/cmdline | tr ' ' '\n' | rg i8042
# Should include: i8042.reset, i8042.nomux
# Should also: mitigations=off, preempt=full, mem_sleep_default=s2idle

# 3. WiFi recovery script is installed
command -v ops-wifi-recover
sudo ops-wifi-recover    # if WiFi doesn't come back after s2idle

# 4. Avahi
getent hosts desktop.local
getent hosts cf19.local

# 5. NFS autofs
systemctl status mnt-desktop.automount
ls /mnt/desktop                # ≤ 3 s, even if desktop is offline

# 6. EXWM session
ls /run/systemd/system/display-manager.service
# Should be present (gdm). Login → EXWM.
# If black screen: Ctrl+Alt+F2, log in to tty2, check
# ~/.local/share/xorg/Xorg.0.log

# 7. Emacs soft-reload
# Inside Emacs: M-x pro/reload-config
# Should reload all 60 modules without errors.

# 8. Tor onion (if allowTorHiddenService was set)
sudo cat /var/lib/tor/ssh_hidden_service/hostname
# Register in pro.hosts.cf19.onion via local.nix on desktop.

# 9. dbus-regression guard
# The override in hosts/cf19/configuration.nix should prevent
# `nixos-rebuild switch` from dropping you to TTY. If it
# happens anyway, check:
systemctl show dbus.service | grep -E 'Reload|Trigger'
```

## huawei

```bash
# 1. SSH keys
ssh-copy-id -i ~/.ssh/id_ed25519.pub az@huawei.local

# 2. SOF audio (snd-intel-dspcfg dsp_driver=1)
lsmod | rg snd_intel_dspcfg
lsmod | rg snd_sof
speaker-test -c 2 -t wav        # should produce sound
alsamixer                       # check that speakers are unmuted

# 3. Intel GPU
cat /proc/cmdline | tr ' ' '\n' | rg i915
# Should include: i915.enable_psr=0, acpi_backlight=native

# 4. Haskell
ghc --version                    # should print GHC version
cabal --version
stack --version
which haskell-language-server-wrapper

# 5. Avahi / NFS — note that huawei is on a different subnet
getent hosts huawei.local
# getent hosts desktop.local is expected to be empty until
# headscale bridges the subnets.
ls /mnt/desktop                  # 3-second timeout (autofs nofail)

# 6. Sway
# Start Sway from a TTY:
sway
# If wl_compositor crashes 2 s after start, check
# ~/.cache/emacs-startup/gdm-exwm.log (the EXWM session launcher
# writes there even when not used by Sway).
```

## vm

```bash
# 1. SSH keys
ssh-copy-id -i ~/.ssh/id_ed25519.pub az@vm.local

# 2. systemctl --failed (the minimal baseline should be clean)
systemctl --failed

# 3. NFS autofs (the one network dependency)
systemctl status mnt-desktop.automount
ls /mnt/desktop                  # ≤ 3 s, even if desktop is offline

# 4. Docker (pro-dev bridge)
docker network ls | rg pro-dev
docker run --rm --network pro-dev alpine:3.20 ip addr

# 5. Nix sanity
nix flake check

# 6. User passwords (the VM starts with empty root password)
sudo passwd az
# Other users (za, la, bo) start as locked — set their passwords
# here if you need them.

# 7. Test the smoke checks
just headless-tests              # if you have a display
just network-contract
```

## Universal (any host)

```bash
# SSH keys (one time)
ssh-keygen -t ed25519 -C "az@$(hostname)" -f ~/.ssh/id_ed25519

# If this host should be reachable from other hosts in the cluster:
ssh-copy-id -i ~/.ssh/id_ed25519.pub az@<other-host>.local

# Or via local.nix on the OTHER host:
#   users.users.az.openssh.authorizedKeys.keys = [
#     "ssh-ed25519 AAAA... az@<this-host>"
#   ];

# Set your AI provider keys
mkdir -p ~/.authinfo
chmod 0600 ~/.authinfo
$EDITOR ~/.authinfo
# Add lines like:
#   machine api.aitunnel.ru  login token  <key>
#   machine openrouter.ai    login token  <key>
#   machine api.openai.com   login openai <key>

# Deploy the AI agent configs
just deploy-agents

# Start EMCP (MCP server inside Emacs)
emacsclient -e '(pro-emcp-server-start)'

# Verify the agent sees the MCP servers
pi -p 'mcp({})'
# Should show: 2/2 servers (emcp, chrome-devtools)

# Initialize submodules (if not done already)
git submodule update --init --recursive

# Re-verify Nix eval
nix eval --json .#nixosConfigurations.$(hostname).config.environment.systemPackages \
  | jq -r '.[]' | rg -c .
# Should be a large number (~hundreds of packages).
```

## Per-host role table

| Host | Roles | NFS | Headscale | LAN-gw |
|------|-------|-----|-----------|--------|
| `desktop` | server, headscale, lan-gw, nfs, tor | server | yes | yes |
| `cf19` | laptop, tor | client | no | no |
| `huawei` | laptop, tor | disabled (different subnet) | no | no |
| `vm` | vm, lab | client | (option does not exist) | no |
