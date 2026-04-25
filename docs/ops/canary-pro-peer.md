Canary plan for pro-peer key sync script
======================================

Purpose
- Safely validate improved pro-peer sync script on a single canary host before rolling out to fleet.

Preconditions
- Operator with SSH access to a canary host.
- Backups of existing authorized_keys present or available via the script backups.

Steps
1. Copy the encrypted authorized_keys.gpg to the canary host at /tmp/test-authorized_keys.gpg (or use the operator-managed secret path).
2. On canary host run (as root):
   - /etc/pro-peer-canary.sh --input /tmp/test-authorized_keys.gpg --out /var/lib/pro-peer/authorized_keys
   This runs in dry-run mode and will print expected actions.
3. Inspect output: it should show backup file name and the mv step (dry-run: would move...). Ensure no unexpected changes.
4. If output acceptable, run actual apply:
   - sudo /etc/pro-peer-sync-keys.sh --input /tmp/test-authorized_keys.gpg --out /var/lib/pro-peer/authorized_keys
5. Verify:
   - ls -l /var/lib/pro-peer/authorized_keys
   - cat /var/lib/pro-peer/authorized_keys | wc -l (expect number of keys)
   - Check SSH connectivity from a test host.

Rollback
- If anything breaks, restore backup created during apply: the script creates /var/lib/pro-peer/authorized_keys.bak.<timestamp>
- Example:
  - sudo cp /var/lib/pro-peer/authorized_keys.bak.20260425T120000Z /var/lib/pro-peer/authorized_keys
  - sudo chown root:root /var/lib/pro-peer/authorized_keys && sudo chmod 600 /var/lib/pro-peer/authorized_keys

Notes
- The canary should be monitored for 24 hours for auth failures. If no issues, schedule rollout to other hosts.
