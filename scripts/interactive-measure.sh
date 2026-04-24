#!/usr/bin/env bash
set -euo pipefail

if ! command -v stress-ng >/dev/null 2>&1; then
  echo "stress-ng is not installed; please install to run interactive measurement"
  exit 0
fi

echo "Starting CPU background load (40s)"
stress-ng --cpu 0 --timeout 40s --metrics-brief >/dev/null 2>&1 &
BG_PID=$!

echo "Running 3 iterations of 1000 'date' calls each and timing them"
for i in 1 2 3; do
  /usr/bin/time -f "Real %R" bash -c 'for j in $(seq 1 1000); do date >/dev/null; done'
done

kill $BG_PID 2>/dev/null || true
echo "Done"
