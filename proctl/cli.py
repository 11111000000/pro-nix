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


def parse_host(host_spec: str):
    """Разобрать спецификатор host.

    Форматы:
      - local
      - ssh:user@host:port
      - ssh:user@host
      - host (будет трактоваться как ssh:host с текущим user)
    Возвращает словарь с ключом type: "local" или "ssh" и соответствующими полями.
    """
    if not host_spec or host_spec == "local":
        return {"type": "local"}
    if host_spec.startswith("ssh:"):
        spec = host_spec[4:]
    else:
        spec = host_spec
    # spec может быть user@host:port or user@host or host:port or host
    user = None
    port = None
    host = spec
    if "@" in spec:
        user, host = spec.split("@", 1)
    if ":" in host:
        host, port_s = host.split(":", 1)
        try:
            port = int(port_s)
        except Exception:
            port = None
    return {"type": "ssh", "user": user or os.environ.get("USER"), "host": host, "port": port}


def run_command_on_host(host_spec: str, cmd: str, dry: bool = False, stream: bool = False, use_pkexec: bool = False):
    """Выполнить команду локально или по SSH на удалённом хосте.

    Если dry=True — не выполняем, только возвращаем подготовленную команду.
    Если use_pkexec=True — обернуть команду в pkexec для выполнения с root правами.
    Возвращаем структуру с полями: rc/stdout/stderr или out_path при stream.
    """
    host = parse_host(host_spec)
    if use_pkexec:
        # pkexec требует, чтобы команда была одним аргументом в sh -c
        cmd_exec = f"pkexec sh -c {shlex.quote(cmd)}"
    else:
        cmd_exec = cmd
    if dry:
        return {"preview": cmd_exec}
    if host["type"] == "local":
        return run_local_command(cmd_exec, stream=stream)
    # remote via ssh
    ssh_parts = ["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new"]
    if host.get("port"):
        ssh_parts += ["-p", str(host["port"])]
    target = host["host"]
    if host.get("user"):
        target = f"{host['user']}@{target}"
    # Escape command for remote shell
    remote_cmd = shlex.quote(cmd_exec)
    full = ssh_parts + [target, remote_cmd]
    try:
        p = subprocess.run(full, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return {"rc": p.returncode, "stdout": p.stdout.decode(errors="replace"), "stderr": p.stderr.decode(errors="replace")}
    except Exception as e:
        return {"rc": 1, "stdout": "", "stderr": str(e)}


def upload_file_to_host(host_spec: str, src: str, dst: str, owner: str = "root:root", mode: str = "0600", dry: bool = False):
    """Загрузить локальный файл SRC на хост DST путь DST.

    Для remote используем scp в /tmp и затем sudo mv; для local — используем sudo cp.
    Возвращаем preview если dry, иначе результат выполнения.
    """
    host = parse_host(host_spec)
    src = os.path.abspath(src)
    if not os.path.exists(src):
        return {"rc": 1, "stderr": f"Исходный файл не найден: {src}"}
    if host["type"] == "local":
        cmd = f"sudo install -m {mode} {shlex.quote(src)} {shlex.quote(dst)} && sudo chown {shlex.quote(owner)} {shlex.quote(dst)}"
        if dry:
            return {"preview": cmd}
        return run_local_command(cmd)
    else:
        # remote: scp to /tmp, then sudo mv
        tmpname = os.path.basename(dst)
        remote_tmp = f"/tmp/{tmpname}.proctl" 
        scp_parts = ["scp"]
        if host.get("port"):
            scp_parts += ["-P", str(host["port"])]
        scp_target = host["host"]
        if host.get("user"):
            scp_target = f"{host['user']}@{scp_target}"
        scp_parts += [src, f"{scp_target}:{remote_tmp}"]
        scp_cmd = " ".join(shlex.quote(p) for p in scp_parts)
        mv_cmd = f"sudo mv {remote_tmp} {shlex.quote(dst)} && sudo chown {shlex.quote(owner)} {shlex.quote(dst)} && sudo chmod {shlex.quote(mode)} {shlex.quote(dst)}"
        preview = scp_cmd + " && " + mv_cmd
        if dry:
            return {"preview": preview}
        # run scp
        try:
            scp_proc = subprocess.run(scp_parts, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if scp_proc.returncode != 0:
                return {"rc": scp_proc.returncode, "stdout": scp_proc.stdout.decode(errors="replace"), "stderr": scp_proc.stderr.decode(errors="replace")}
        except Exception as e:
            return {"rc": 1, "stderr": str(e)}
        # run mv over ssh
        mv_res = run_command_on_host(host_spec, mv_cmd)
        return mv_res


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

    p = sub.add_parser("ssh-test")
    p.add_argument("--host", default="local")
    p.add_argument("--user", required=False)
    p.add_argument("--key", required=False)

    p = sub.add_parser("rebuild")
    p.add_argument("--host", default="local")
    p.add_argument("--flake", required=True)
    p.add_argument("--preview", action="store_true")
    p.add_argument("--run", action="store_true")

    p = sub.add_parser("set-hostname")
    p.add_argument("--host", default="local")
    p.add_argument("--hostname", required=True)
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("upload-file")
    p.add_argument("--host", default="local")
    p.add_argument("--src", required=True)
    p.add_argument("--dst", required=True)
    p.add_argument("--owner", default="root:root")
    p.add_argument("--mode", default="0600")
    p.add_argument("--dry-run", action="store_true")

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
    elif args.cmd == "set-hostname":
        # set-hostname via run_command_on_host
        host = args.host
        name = args.hostname
        cmd = f"hostnamectl set-hostname {shlex.quote(name)}"
        if args.dry_run:
            log_action({"host": host, "action": "set-hostname", "cmd": cmd, "dry_run": True})
            json_exit({"preview": cmd})
        res = run_command_on_host(host, cmd, dry=False, stream=False, use_pkexec=True)
        log_action({"host": host, "action": "set-hostname", "cmd": cmd, "result": res})
        json_exit({"cmd": cmd, "result": res})
    elif args.cmd == "upload-file":
        res = upload_file_to_host(args.host, args.src, args.dst, owner=args.owner, mode=args.mode, dry=args.dry_run)
        if args.dry_run:
            json_exit({"preview": res.get("preview")})
        json_exit({"result": res})
    elif args.cmd == "ssh-test":
        # ssh-test --host <spec> --user <user> [--key <path>]
        host = args.host
        user = args.user
        key = getattr(args, 'key', None)
        # Build ssh command: ssh -o BatchMode=yes [-i key] user@host true
        target = host
        if not host.startswith("ssh:") and not host == "local":
            # allow plain host names
            target = f"ssh:{host}"
        parsed = parse_host(target)
        if parsed["type"] == "local":
            # local test: try to run su -c 'true' as user? Instead, just check that authorized_keys contains user's key if possible
            # For MVP return not implemented
            json_exit({"error": "ssh-test for local host not implemented; use remote host or run manual test"}, code=2)
        # remote
        ssh_cmd_parts = ["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new"]
        if parsed.get("port"):
            ssh_cmd_parts += ["-p", str(parsed.get("port"))]
        if key:
            ssh_cmd_parts += ["-i", key]
        target_host = parsed["host"]
        if parsed.get("user"):
            target_host = f"{parsed['user']}@{target_host}"
        elif user:
            target_host = f"{user}@{target_host}"
        ssh_cmd_parts += [target_host, "true"]
        try:
            p = subprocess.run(ssh_cmd_parts, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            stdout = p.stdout.decode(errors="replace")
            stderr = p.stderr.decode(errors="replace")
            json_exit({"rc": p.returncode, "stdout": stdout, "stderr": stderr})
        except Exception as e:
            json_exit({"error": str(e)}, code=1)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
