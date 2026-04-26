# Onboarding Wizard — UX and Flow

This document describes the interactive onboarding wizard for operator‑driven enrollment of hosts into the pro-nix mesh. The wizard is available as a TUI (Textual) app and as an Emacs interactive workflow. The UI calls `proctl` to perform actions.

Guiding principles
- Operator-driven: secrets and sensitive blobs are provided by the operator (upload), not generated silently.
- Safe-by-default: dangerous operations require typed confirmation ("APPLY"), backups are created automatically and a restore path is offered.
- Observable: long-running operations stream logs; actions are recorded in an audit log.

Screens / Steps

1) Welcome / Host selection
- List known hosts (from flake config or local inventory) and allow manual host spec (user@host:port). Choose host.

2) Join-secret
- Prompt for path to join-secret file (local path). The wizard calls `proctl check-join-secret --host <spec> --secret-file <path>`.
- If invalid: show error and explanation. Offer to set secret on host via `proctl set-join-secret` (requires as_root). If the host has no secret, setting it will be required for the next steps.

3) Discovery options (only shown after secret validated)
- WireGuard Overlay: option to upload prepared wg0.conf (local file) and run `wg-quick up` on host. Upload is done via `proctl upload-file` and `proctl exec --cmd 'wg-quick up /etc/wireguard/wg0.conf' --as-root`.
- Avahi mDNS: enable Avahi advertising on overlay interface. Checklist: overlay interface present (proctl list-ifaces); if not present, the wizard suggests to upload/bring up WireGuard first.
- Tor Hidden Service: upload encrypted hidden service blob (encrypted by operator), then `proctl exec` to place it and restart tor (if applicable).

4) Keys sync
- Upload authorized_keys.gpg via `proctl upload-file` to /etc/pro-peer/authorized_keys.gpg (as_root) then run `proctl exec --cmd '/etc/ops-pro-peer-sync-keys.sh --input /etc/pro-peer/authorized_keys.gpg --out /var/lib/pro-peer/authorized_keys' --as-root`. Wizard checks /var/lib/pro-peer/authorized_keys afterwards.

5) Review & APPLY
- Provide preview of commands to run (dry-run mode) and a typed confirmation box where user must type "APPLY" to actually execute. Each step will create backups and list the backup paths.

6) Completion
- Show summary and quick actions: tail logs, test SSH, create rollback, re-run diagnostics.

Errors and Rollback
- On error, the wizard displays the log and offers a Restore button (calls proctl.restore-backup with the earlier backup path).

Security considerations
- proctl never logs secret contents.
- Files uploaded are stored with strict permissions (600) and backups placed in /var/lib/pro-nix/backups.
