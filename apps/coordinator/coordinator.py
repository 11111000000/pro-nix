#!/usr/bin/env python3
"""Minimal coordinator exposing POST /tasks to insert tasks into local sqlite queue."""
import os
import json
import sqlite3
import time
import uuid
from pathlib import Path
from flask import Flask, request, jsonify

app = Flask(__name__)

DB_PATH = os.environ.get("AGENTS_QUEUE_DB", str(Path.home() / ".local" / "state" / "agents" / "queue.sqlite"))
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

@app.route('/tasks', methods=['POST'])
def add_task():
    data = request.get_json() or {}
    task_id = data.get('task_id') or str(uuid.uuid4())
    payload = json.dumps(data.get('payload', {}))
    conn = sqlite3.connect(DB_PATH)
    ensure_schema(conn)
    conn.execute('insert into tasks (id,payload,created_at) values (?,?,?)', (task_id, payload, int(time.time())))
    conn.commit()
    return jsonify({'task_id': task_id})

@app.route('/health')
def health():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=8080)
