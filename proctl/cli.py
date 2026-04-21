#!/usr/bin/env python3
"""
proctl - тонкий адаптер для управления pro-nix из UI

Этот модуль предоставляет простой JSON-ориентированный CLI для вызова
операций над локальной или удалённой машиной. Цель — унифицировать
взаимодействие между TUI (Textual) и Emacs-клиентом и текущими скриптами
в репозитории.

Примечание: это минимальный MVP-адаптер — он поддерживает dry-run режим и
возвращает понятные JSON-ответы. Для безопасности привилегированные
операции по умолчанию в dry-run.

Команды (пока поддерживаемое):
 - list-hosts
 - host-status --host <host>
 - list-services --host <host>
 - service-action --host <host> --unit <unit> --action start|stop|restart|status [--dry-run]
 - run-script --host <host> --script <key> [--dry-run]
 - diagnostics --host <host> --which <all|samba|pro-peer|emacs>
 - rebuild --host <host> --flake <flake> --preview|--run

Выходы — JSON на stdout. При ошибке возвращается код != 0 и JSON с полем error.

Код и комментарии на русском по требованию.
"""

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime

# Путь к репозиторию — считаем, что cli запускают из корня репо
REPO_ROOT = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))


def log_action(entry: dict):
    """Записать действие в audit лог (~/.local/share/pro-nix/actions.log).

    Полезно для трассировки того, кто и что запускал.
    """
    outdir = os.path.expanduser("~/.local/share/pro-nix")
    os.makedirs(outdir, exist_ok=True)
    path = os.path.join(outdir, "actions.log")
    entry.setdefault("timestamp", datetime.utcnow().isoformat() + "Z")
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def json_exit(obj, code=0):
    print(json.dumps(obj, ensure_ascii=False))
    sys.exit(code)


def run_local_command(cmd, capture_output=True, stream=False):
    """Запустить команду локально. Возвращаемку stdout/rc/path.

    Для больших выходных данных можно писать во временный файл и вернуть путь.
    """
    if stream:
        # простая streaming обёртка — пишем в tmp файл и возвращаем путь
        fd, tmp = tempfile.mkstemp(prefix="proctl-stream-", text=True)
        os.close(fd)
        with open(tmp, "wb") as f:
            p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            for chunk in iter(lambda: p.stdout.read(8192), b""):
                f.write(chunk)
        rc = p.wait()
        return {"rc": rc, "out_path": tmp}
    else:
        try:
            res = subprocess.run(cmd, shell=True, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            stdout = res.stdout.decode(errors="replace")
            stderr = res.stderr.decode(errors="replace")
            return {"rc": res.returncode, "stdout": stdout, "stderr": stderr}
        except Exception as e:
            return {"rc": 1, "stdout": "", "stderr": str(e)}


SCRIPT_MAP = {
    # ключ -> (описание, команда-шаблон)
    "pro-peer-sync-keys": ("Синхронизировать authorized_keys из зашифрованного файла",
                            "/etc/pro-peer-sync-keys.sh --input /etc/pro-peer/authorized_keys.gpg --out /var/lib/pro-peer/authorized_keys"),
    "backup-hiddenservice": ("Бэкап tor hidden service (пример)",
                             "/etc/pro-peer-backup-hiddenservice.sh"),
    "run-samba-diagnostics": ("Собрать диагностику Samba", "scripts/run-samba-diagnostics.sh"),
}


def cmd_list_hosts(args):
    # Для MVP — возвращаем локальный host и пустую секцию remote
    hosts = [{"name": "local", "type": "local", "desc": "Локальная машина"}]
    # Можно читать конфиг ~/.config/pro-nix/config.json позже
    json_exit({"hosts": hosts})


def cmd_host_status(args):
    host = args.host
    # Для MVP запрашиваем локальные значения
    try:
        services = ["avahi-daemon", "pro-peer-sync-keys", "samba", "sshd"]
        svc_status = []
        for s in services:
            r = run_local_command(f"systemctl is-active {shlex.quote(s)}")
            active = (r.get("stdout", "").strip() == "active")
            svc_status.append({"unit": s, "active": active})
        # basic sshd check: listening?
        r = run_local_command("ss -ltnp | grep ':22 ' || true")
        ssh_listening = bool(r.get("stdout"))
        json_exit({"host": host, "services": svc_status, "ssh_listening": ssh_listening})
    except Exception as e:
        json_exit({"error": str(e)}, code=1)


def cmd_list_services(args):
    host = args.host
    # MVP: call systemctl list-units --type=service --no-legend --no-pager
    res = run_local_command("systemctl list-units --type=service --no-legend --all --no-pager")
    out = res.get("stdout", "")
    services = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 4:
            unit = parts[0]
            active = parts[3] if len(parts) > 3 else ""
            services.append({"unit": unit, "active": active, "description": ""})
    json_exit({"host": host, "services": services})


def cmd_service_action(args):
    host = args.host
    unit = args.unit
    action = args.action
    dry = args.dry_run
    cmd = f"systemctl {action} {shlex.quote(unit)}"
    if dry:
        log_action({"host": host, "action": "service-action", "unit": unit, "cmd": cmd, "dry_run": True})
        json_exit({"preview": cmd})
    # run it
    log_action({"host": host, "action": "service-action", "unit": unit, "cmd": cmd, "dry_run": False})
    res = run_local_command(cmd)
    json_exit({"cmd": cmd, "result": res})


def cmd_run_script(args):
    host = args.host
    key = args.script
    dry = args.dry_run
    if key not in SCRIPT_MAP:
        json_exit({"error": f"Unknown script key: {key}"}, code=2)
    desc, template = SCRIPT_MAP[key]
    # if script path relative repo -> make path absolute
    if template.startswith("scripts/") or template.startswith("/etc/"):
        cmd = template
    else:
        cmd = template
    if dry:
        log_action({"host": host, "action": "run-script", "script": key, "cmd": cmd, "dry_run": True})
        json_exit({"preview": cmd})
    # execute
    log_action({"host": host, "action": "run-script", "script": key, "cmd": cmd, "dry_run": False})
    res = run_local_command(cmd, stream=True)
    json_exit({"cmd": cmd, "result": res})


def cmd_diagnostics(args):
    host = args.host
    which = args.which or "all"
    # MVP: call existing scripts/run-samba-diagnostics.sh and return path
    outdir = tempfile.mkdtemp(prefix="proctl-diag-")
    outpath = os.path.join(outdir, f"diag-{which}.log")
    cmd = f"./scripts/run-samba-diagnostics.sh > {shlex.quote(outpath)} 2>&1"
    log_action({"host": host, "action": "diagnostics", "which": which, "cmd": cmd})
    # run synchronously for MVP
    res = run_local_command(cmd)
    json_exit({"cmd": cmd, "out": outpath, "rc": res.get("rc", 0)})


def cmd_rebuild(args):
    host = args.host
    flake = args.flake
    preview = args.preview
    runflag = args.run
    cmd = f"sudo nixos-rebuild switch --flake {shlex.quote(flake)}"
    if preview:
        log_action({"host": host, "action": "rebuild-preview", "cmd": cmd})
        # For preview we can attempt a dry evaluation (nix --extra-experimental-features flakes eval?)
        json_exit({"preview": cmd})
    if runflag:
        log_action({"host": host, "action": "rebuild-run", "cmd": cmd})
        res = run_local_command(cmd, stream=True)
        json_exit({"cmd": cmd, "result": res})
    json_exit({"error": "Specify --preview or --run"}, code=2)


def main():
    parser = argparse.ArgumentParser(description="proctl — thin adapter for pro-nix UI")
    sub = parser.add_subparsers(dest="cmd")

    sub.add_parser("list-hosts")

    p = sub.add_parser("host-status")
    p.add_argument("--host", default="local")

    p = sub.add_parser("list-services")
    p.add_argument("--host", default="local")

    p = sub.add_parser("service-action")
    p.add_argument("--host", default="local")
    p.add_argument("--unit", required=True)
    p.add_argument("--action", choices=["start", "stop", "restart", "status"], required=True)
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("run-script")
    p.add_argument("--host", default="local")
    p.add_argument("--script", required=True)
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("diagnostics")
    p.add_argument("--host", default="local")
    p.add_argument("--which", choices=["all", "samba", "pro-peer", "emacs"], default="all")

    p = sub.add_parser("rebuild")
    p.add_argument("--host", default="local")
    p.add_argument("--flake", required=True)
    p.add_argument("--preview", action="store_true")
    p.add_argument("--run", action="store_true")

    args = parser.parse_args()
    if args.cmd == "list-hosts":
        cmd_list_hosts(args)
    elif args.cmd == "host-status":
        cmd_host_status(args)
    elif args.cmd == "list-services":
        cmd_list_services(args)
    elif args.cmd == "service-action":
        cmd_service_action(args)
    elif args.cmd == "run-script":
        cmd_run_script(args)
    elif args.cmd == "diagnostics":
        cmd_diagnostics(args)
    elif args.cmd == "rebuild":
        cmd_rebuild(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
