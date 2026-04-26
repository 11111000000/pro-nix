#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root to enable zram: sudo $0"
  exit 2
fi

echo "This script will (optionally) create a zram swap device. It will NOT run unless you confirm."
read -p "Proceed to show plan? (y/N) " yes
if [ "${yes,,}" != "y" ]; then
  echo "Aborting."
  exit 0
fi

awk '/MemTotal|MemFree|SwapTotal|SwapFree/ {print}' /proc/meminfo

RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
RAM_MB=$((RAM_KB/1024))
RECOMM_MB=$(( RAM_MB / 2 ))
if [ $RECOMM_MB -gt 16384 ]; then RECOMM_MB=16384; fi
echo "Recommended zram size: ${RECOMM_MB}M (50% RAM, capped 16G)"

read -p "Enter zram size in MB (or press Enter to use recommended ${RECOMM_MB}): " input
SIZE_MB=${input:-$RECOMM_MB}

echo "Will enable zram0 of size ${SIZE_MB}M and add as swap"
read -p "Confirm final apply (this will create device and enable swap)? (type ENABLE): " confirm
if [ "$confirm" != "ENABLE" ]; then
  echo "Not confirmed. Exiting."
  exit 0
fi

modprobe zram max_comp_streams=4 || { echo "modprobe failed"; exit 1; }
echo $((SIZE_MB * 1024 * 1024)) > /sys/block/zram0/disksize
mkswap /dev/zram0
swapon -p 5 /dev/zram0
echo "zram enabled:"
swapon --show
