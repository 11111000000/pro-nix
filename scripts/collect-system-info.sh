#!/usr/bin/env bash
set -euo pipefail

echo "=== HOST / KERNEL ==="
uname -a
cat /etc/os-release 2>/dev/null || true

echo
echo "=== CPU ==="
lscpu || cat /proc/cpuinfo | sed -n '1,40p'

echo
echo "=== MEMORY ==="
free -h
awk '/MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree/ {print}' /proc/meminfo

echo
echo "=== SWAP ==="
swapon --show || echo "no swap active or insufficient privileges to show"
lsblk -o NAME,TYPE,SIZE,ROTA,MOUNTPOINT || true

echo
echo "=== ZRAM / ZSWAP ==="
if [ -d /sys/block/zram0 ]; then
  echo "zram devices present:"
  ls /sys/block | grep zram || true
  for d in /sys/block/zram*; do
    echo "device: $d"
    cat $d/disksize 2>/dev/null || true
  done
else
  echo "zram: none or not accessible"
fi
echo "zswap enabled?:"
cat /sys/module/zswap/parameters/enabled 2>/dev/null || true

echo
echo "=== SYSCTL (selection) ==="
for k in vm.swappiness vm.vfs_cache_pressure vm.dirty_ratio vm.dirty_background_ratio vm.overcommit_memory vm.overcommit_ratio; do
  printf "%-30s: " "$k"
  sysctl -n $k 2>/dev/null || echo n/a
done

echo
echo "=== CPU GOV / FREQUENCIES ==="
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
  gov="$cpu/cpufreq/scaling_governor"
  if [ -f "$gov" ]; then
    echo "$(basename $cpu): $(cat $gov)"
  fi
done || true

echo
echo "=== I/O SCHEDULERS ==="
for b in /sys/block/*; do
  if [ -f "$b/queue/scheduler" ]; then
    echo "$(basename $b) -> $(cat $b/queue/scheduler)"
  fi
done

echo
echo "=== THERMALS / TEMPS (sensors if available) ==="
which sensors >/dev/null 2>&1 && sensors || echo "sensors not installed or not available"

echo
echo "=== SYSTEMD OOMD / SLICES ==="
systemctl is-active systemd-oomd.service >/dev/null 2>&1 && systemctl status systemd-oomd --no-pager || echo "systemd-oomd: not active or not available"
systemctl list-slices --no-pager 2>/dev/null || true

echo
echo "=== USER LIMITS ==="
ulimit -a || true

echo
echo "=== TOP PROCESS SNAPSHOT (RES sorted) ==="
ps aux --sort=-rss | head -n 25 || true

echo
echo "=== LAST KERNEL MESSAGES (OOM/THERMAL) ==="
dmesg | tail -n 200 || true
