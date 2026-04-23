Title: Plan 02 — Security & Operational Control

Intent
- Maintain strong default safety for Samba exposure with simple operator controls and verifiable boundaries.

Pressure
- Ops/Security: reduce attack surface while allowing easy toggling and audits.

Surface Impact
- Access scoping (hosts allow/deny), firewall strategy, operational scripts, diagnostics.

Steps
1) Network scoping at service layer
   - Configure "hosts allow" = RFC1918 + loopback; "hosts deny" = 0.0.0.0/0.
   - Keep SMB1 disabled; prefer encryption and signing when available.
2) Firewall policy
   - Rely on services.samba.openFirewall for ports; avoid iptables extraCommands to prevent nft/iptables drift.
3) Operational controls
   - Provide scripts/pro-samba-toggle.sh for quick on/off/restart/status without config changes.
   - Keep scripts/run-samba-diagnostics.sh to capture ports, services, logs, and avahi state.
4) Auditing & Docs
   - Update security notes (docs/ops/samba-hardening.md) to reflect layered controls and mDNS publishing.

Proof / Verify
- From a non-RFC1918 source (if available), confirm access denied.
- From LAN, confirm access allowed; test guest/public and user-restricted shares.
- Review logs: journalctl -u samba-smbd and avahi; ensure no repeated auth/signing failures.

Risks / Residuals
- Some guest networks use client isolation; discovery then fails by design. Mitigate by connecting directly via IP.

Exit Criteria
- Access permitted only from RFC1918 by Samba layer; operational script works; diagnostics capture mDNS and SMB status.
