#!/usr/bin/env python3
"""
Textual TUI для управления pro-nix (MVP prototype).

Это минималистичный интерфейс, использующий proctl как backend. Пока
поддерживает: список хостов, host status, list services и run-script preview.

Комментарии и docstrings на русском.
"""

from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static, Button, Input, TextLog, DataTable, TreeControl, TreeNode
from textual.containers import Horizontal, Vertical
import subprocess
import json
import os
import shlex

PROCTL = os.path.join(os.path.dirname(os.path.dirname(__file__)), "proctl/cli.py")


def call_proctl(args):
    cmd = [PROCTL] + args
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode != 0:
        try:
            return {"error": p.stderr.decode(errors="replace")}
        except Exception:
            return {"error": str(p.stderr)}
    try:
        return json.loads(p.stdout.decode(errors="replace"))
    except Exception as e:
        return {"error": f"parse error: {e}", "raw": p.stdout.decode(errors="replace")}


class HostsTree(Static):
    """Панель списка хостов"""
    def compose(self) -> ComposeResult:
        yield TreeControl("Hosts", {})


class MainApp(App):
    CSS_PATH = ""

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            with Vertical():
                yield Static("Hosts", id="hosts_label")
                self.tree = TreeControl("Hosts", {})
                yield self.tree
                yield Button("Refresh Hosts", id="refresh_hosts")
            with Vertical():
                yield Static("Main", id="main_label")
                self.main_log = TextLog()
                yield self.main_log
                yield Button("Host Status", id="host_status")
                yield Button("List Services", id="list_services")
                yield Button("Run Onboarding Wizard", id="onboard_wizard")
                yield Button("Run Pro-peer Sync (preview)", id="run_sync")
        yield Footer()

    def on_mount(self):
        # initial load hosts
        self.load_hosts()

    def load_hosts(self):
        res = call_proctl(["list-hosts"])
        self.tree.root.clear()
        if "hosts" in res:
            for h in res["hosts"]:
                self.tree.root.add(h["name"], h)
        else:
            self.main_log.write(f"Error loading hosts: {res.get('error')}")

    async def on_button_pressed(self, event):
        id = event.button.id
        if id == "refresh_hosts":
            self.load_hosts()
        elif id == "host_status":
            # find selected host or default local
            host = "local"
            res = call_proctl(["host-status", "--host", host])
            self.main_log.clear()
            self.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))
        elif id == "list_services":
            host = "local"
            res = call_proctl(["list-services", "--host", host])
            self.main_log.clear()
            self.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))
        elif id == "run_sync":
            host = "local"
            res = call_proctl(["run-script", "--host", host, "--script", "pro-peer-sync-keys", "--dry-run"])
            self.main_log.clear()
            self.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))
        elif id == "onboard_wizard":
            # Simple linear wizard prototype: set hostname, upload keys, sync
            host = "local"
            # Step 1: ask hostname via input (blocking for prototype)
            from textual.widgets import Input
            self.main_log.write("--- Onboarding Wizard ---\n")
            self.main_log.write("Шаг 1: введите hostname (или оставьте пустым): ")
            # For prototype, we read from ENV or use example
            newname = os.environ.get("PRO_NIX_TEST_HOSTNAME", "")
            if newname:
                self.main_log.write(f"(использован тестовый hostname: {newname})\n")
                res = call_proctl(["set-hostname", "--host", host, "--hostname", newname, "--dry-run"]) 
                self.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))
            else:
                self.main_log.write("(нет hostname; пропускаем)\n")
            # Step 2: keys upload (preview)
            self.main_log.write("Шаг 2: preview upload authorized_keys.gpg (используйте PRO_NIX_TEST_KEY env для пути)\n")
            src = os.environ.get("PRO_NIX_TEST_KEY", "")
            if src and os.path.exists(src):
                res = call_proctl(["upload-file", "--host", host, "--src", src, "--dst", "/etc/pro-peer/authorized_keys.gpg", "--dry-run"]) 
                self.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))
            else:
                self.main_log.write("(нет тестового ключа; пропускаем загрузку)\n")
            # Step 3: sync preview
            res = call_proctl(["run-script", "--host", host, "--script", "pro-peer-sync-keys", "--dry-run"]) 
            self.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    app = MainApp()
    app.run()
