Title: Plan 01 — Android Discovery & Compatibility

Intent
- Make Samba shares reliably discoverable and accessible from Android across typical Wi‑Fi/LAN setups without manual IP entry.

Pressure
- Feature: improve UX (zero‑config discovery) while preserving baseline safety.

Surface Impact
- mDNS advertisement for _smb._tcp, Samba signing policy (desired), share sections correctness, service enablement by default.

Scope
- Service discovery and client compatibility only. No changes to core access policy beyond what’s needed for compatibility.

Steps
1) Discovery via mDNS
   - Ensure avahi-daemon is enabled and add /etc/avahi/services/samba.service with _smb._tcp on 445.
2) Android compatibility tweaks
   - Keep SMB1 disabled (server min protocol = SMB2).
   - Set "server signing" = "desired" and "client signing" = "desired".
   - Keep "smb encrypt" = "desired".
3) Enable by default
   - services.samba.enable = mkDefault true; services.samba.openFirewall = mkDefault true.
4) Correct section layout
   - Use services.samba.settings."global" and one section per share.

Proof / Verify
- Build switch; check:
  - ss -ltnp | grep -E ':(139|445)'
  - avahi-browse -rt _smb._tcp (service visible)
  - testparm -s (SMB2+, signing desired)
- Android: browse network; smb://<server-ip>/public connects.

Risks / Tradeoffs
- Signing "desired" is softer than "required"; mitigated in Plan 02 by layered controls.

Exit Criteria
- Discovery works on at least two common Android file managers; direct IP connect succeeds; no errors in smbd logs related to signing.
