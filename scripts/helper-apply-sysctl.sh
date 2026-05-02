#!/usr/bin/env bash
set -euo pipefail

echo "This script will show recommended sysctl changes for interactivity."
echo "Recommended values (safe defaults for a dev laptop):"
cat <<'EOF'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 5
vm.dirty_ratio = 15
vm.overcommit_memory = 1   # optional - changes allocation behavior
EOF

read -p "Apply these sysctl values temporarily now? (y/N) " ans
if [ "${ans,,}" = "y" ]; then
  echo "Applying sysctl changes (temporary)"
  sudo sysctl -w vm.swappiness=10
  sudo sysctl -w vm.vfs_cache_pressure=50
  sudo sysctl -w vm.dirty_background_ratio=5
  sudo sysctl -w vm.dirty_ratio=15
  sudo sysctl -w vm.overcommit_memory=1
  echo "Applied. These changes are non-persistent (reboot will revert)."
else
  echo "No changes applied."
fi
