#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

echo "controlplane e2e: start mocked model-client, coordinator, worker in background"

# start a mocked model client (simple HTTP echo)
python3 - <<'PY' &
from flask import Flask, request, jsonify
app=Flask(__name__)
@app.route('/v1/predict', methods=['POST'])
def p():
    data=request.get_json() or {}
    return jsonify({'mocked': True, 'input': data})
@app.route('/health')
def h():
    return jsonify({'status':'ok'})
app.run(port=31415)
PY
MC_PID=$!
sleep 0.5

# start coordinator
python3 "$root/apps/coordinator/coordinator.py" &
COORD_PID=$!
sleep 0.5

# start worker
python3 "$root/apps/worker/worker.py" &
WORKER_PID=$!
sleep 0.5

TASK_ID=$(curl -s -X POST -H 'Content-Type: application/json' -d '{"payload": {"input": {"text":"hello"}}}' http://127.0.0.1:8080/tasks | jq -r .task_id)
echo "submitted task: $TASK_ID"

for i in {1..20}; do
  if [ -f "$HOME/.local/state/agents/transcripts/$TASK_ID.json" ]; then
    echo "transcript found"
    cat "$HOME/.local/state/agents/transcripts/$TASK_ID.json"
    break
  fi
  sleep 1
done

kill $MC_PID $COORD_PID $WORKER_PID || true

echo "e2e: OK"
