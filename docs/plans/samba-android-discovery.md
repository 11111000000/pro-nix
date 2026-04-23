Title: Samba Discovery on Android — Secure-by-Default Plan

Intent
- Ensure Samba shares are reliably discoverable from Android while keeping LAN exposure safe by default.

Scope
- All hosts managed by this repo. Samba enabled by default with LAN-only access, mDNS discovery, and Android-compatible signing policy.

Context and Problem
- Current module disables Samba by default and applies firewall iptables rules that may not be effective on nft-based systems.
- Android discovery often relies on mDNS (DNS-SD, _smb._tcp) and fails when only NetBIOS is present or when SMB signing is too strict (required).

Decisions
1) Enable Samba by default for all hosts (mkDefault true) so it comes up whenever an interface is present.
2) Advertise via mDNS by installing an Avahi service file for _smb._tcp on port 445. Keep Avahi enabled and publishing.
3) Keep protocol hardening (min SMB2, disable SMB1). Use signing "desired" (not "required") for Android compatibility; encryption remains "desired".
4) Restrict access to RFC1918 ranges via Samba "hosts allow"/"hosts deny" (service-level filter independent from firewall backend).
5) Remove custom iptables drop rules; rely on: (a) Samba hosts allow, (b) NixOS firewall openFirewall for Samba ports.
6) Provide a small helper script to enable/disable Samba services quickly at runtime.

Implementation Outline
- Module changes (modules/pro-storage.nix):
  - services.samba.enable = lib.mkDefault true; services.samba.openFirewall = lib.mkDefault true.
  - global: keep SMB2+, signing/encryption = desired, add hosts allow/deny, keep guest policy as-is.
  - Add environment.etc."avahi/services/samba.service" with _smb._tcp advertisement.
  - Keep Avahi enabled/publish.
  - Remove firewall.extraCommands iptables block (nft conflict risk) but leave other unrelated ports.
- Script (scripts/pro-samba-toggle.sh): start/stop/status for Samba and Avahi; no config mutation.

Verification Steps
1) Rebuild: nixos-rebuild switch --flake .#<host>
2) Server checks:
   - systemctl status samba-smbd samba-nmbd avahi-daemon
   - ss -ltnp | grep -E ':(139|445)'
   - testparm -s | grep -E 'server (min protocol|min protocol)|signing|hosts allow'
   - avahi-browse -rt _smb._tcp
3) Android client:
   - In a file manager supporting SMB2, browse network or connect to smb://<server-ip>/public
   - If browse works: discovery path OK. If direct IP works but browse not: re-check Avahi advertisement.
4) Logs: journalctl -u samba-smbd -e while attempting Android access; look for signing/auth errors.

Security Notes
- Access limited to private RFC1918 networks at the Samba layer (hosts allow/deny).
- SMB1 disabled; SMB2+ only.
- Signing/encryption desired maintains compatibility but allows stronger clients to secure sessions.
- Guest-only limited to the public share; per-host share requires explicit users.

Rollback
- To disable Samba globally: set services.samba.enable = false in a host overlay or run the toggle script to stop services.

Open Questions
- If any hosts still fail to start nmbd on wifi-only setups, consider disabling NetBIOS browsing and relying solely on mDNS; revisit if required.
