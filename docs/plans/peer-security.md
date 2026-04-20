# Security and operational guidance for peer networking

This file summarises key security recommendations applicable across the peer networking plans.

1. SSH keys and authorized_keys
- Exchange public keys out of band (e.g. physically or via an encrypted channel).
- Consider adding `from="host.example.org"` and `command="/usr/local/bin/nix-receive-guard.sh"` restrictions in `authorized_keys`.

2. Hidden service keys (Tor)
- Keep HiddenServiceDir private and with 0700 permissions. Backup keys securely if you want to preserve the onion address.

3. Disk management
- Enforce GC policies on receiving nodes: `nix-collect-garbage -d` or `nix-collect-garbage --delete-older-than 30d`.

4. Auditing and logs
- Keep logs of transfers and regularly review them.
