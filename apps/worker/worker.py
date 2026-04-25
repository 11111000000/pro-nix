#!/usr/bin/env python3
"""Minimal worker that polls a local sqlite queue file for tasks.

Behavior:
- tasks stored in ~/.local/state/agents/queue.sqlite (table tasks)
- worker claims a task, calls model-client, writes transcript
"""
import os
import json
import sqlite3
import time
import requests
from pathlib import Path

DB_PATH = os.environ.get("AGENTS_QUEUE_DB", str(Path.home() / ".local" / "state" / "agents" / "queue.sqlite"))
TRANS_DIR = Path(os.environ.get("AGENTS_TRANS_DIR", str(Path.home() / ".local" / "state" / "agents" / "transcripts")))
MODEL_CLIENT_URL = os.environ.get("MODEL_CLIENT_URL", "http://127.0.0.1:31415/v1/predict")

os.makedirs(TRANS_DIR, exist_ok=True)
os.makedirs(Path(DB_PATH).parent, exist_ok=True)

def ensure_schema(conn):
    conn.execute('''
    create table if not exists tasks (
      id text primary key,
      payload text,
      status text default 'pending',
      created_at integer
    )
    ''')
    conn.commit()

def claim_task(conn):
    cur = conn.cursor()
    cur.execute("select id,payload from tasks where status='pending' order by created_at limit 1")
    row = cur.fetchone()
    if not row:
        return None
    task_id, payload = row
    cur.execute("update tasks set status='running' where id=?", (task_id,))
    conn.commit()
    return task_id, json.loads(payload)

def write_transcript(task_id, transcript):
    fn = TRANS_DIR / f"{task_id}.json"
    with open(fn, 'w') as f:
        json.dump(transcript, f, indent=2)

def call_model_client(input_payload):
    try:
        r = requests.post(MODEL_CLIENT_URL, json=input_payload, timeout=30)
        return r.json()
    except Exception as e:
        return {"error": str(e)}

def main():
    conn = sqlite3.connect(DB_PATH)
    ensure_schema(conn)
    while True:
        task = claim_task(conn)
        if not task:
            time.sleep(1)
            continue
        task_id, payload = task
        start = int(time.time())
        result = call_model_client(payload.get('input', {}))
        transcript = {
            'task_id': task_id,
            'started_at': start,
            'finished_at': int(time.time()),
            'payload': payload,
            'result': result,
        }
        write_transcript(task_id, transcript)
        conn.execute("update tasks set status='done' where id=?", (task_id,))
        conn.commit()

if __name__ == '__main__':
    main()
