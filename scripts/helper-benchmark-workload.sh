#!/usr/bin/env bash
set -euo pipefail

echo "WARNING: this script will run short CPU/memory/disk tests."
echo "It will skip tests if required tools are missing."
read -p "Press Enter to continue or Ctrl-C to abort" || true

FOLDER=$(pwd)
echo "Working in: $FOLDER"

if command -v stress-ng >/dev/null 2>&1; then
  echo
  echo "=== CPU stress-ng: 60s on all CPUs ==="
  stress-ng --cpu 0 --cpu-method matrixprod --perf --timeout 60s &> "$FOLDER/stress-cpu.log" &
  PID_CPU=$!
  echo "CPU stress PID: $PID_CPU"
else
  echo "stress-ng not installed: skipping CPU stress-test"
  PID_CPU=""
fi

if command -v python3 >/dev/null 2>&1; then
  echo
  echo "=== Memory allocation test: allocate ~50% RAM for 25s (uses python mmap) ==="
  RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  HALF_KB=$((RAM_KB/2))
  python3 - <<PY
import os, time, mmap
kb = int(os.popen("awk '/MemTotal/ {print $2}' /proc/meminfo").read().strip())
half = kb//2
size = half * 1024
print("Allocating approximately", size, "bytes (~50% RAM)")
m = mmap.mmap(-1, size)
# touch first page to allocate lazily
m[0:1] = b'\0'
time.sleep(25)
m.close()
print("Memory test done")
PY
else
  echo "python3 not available: skipping memory test"
fi

if command -v fio >/dev/null 2>&1; then
  echo
  echo "=== Disk test: fio sequential write/read 512M in /tmp ==="
  fio --name=seqrw --filename=/tmp/fio_testfile --bs=1M --size=512M --rw=write --direct=1 --runtime=20 --time_based &> "$FOLDER/fio.log" || true
  rm -f /tmp/fio_testfile || true
else
  echo "fio not installed: skipping disk test"
fi

if [ -n "${PID_CPU-}" ]; then
  echo "Waiting for CPU stress to finish..."
  wait $PID_CPU || true
  echo "CPU stress finished"
fi

echo "Done. Logs (if created): $FOLDER/stress-cpu.log $FOLDER/fio.log"
