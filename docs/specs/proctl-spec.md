# proctl — CLI control surface specification

This document specifies the command API for the `proctl` local CLI that provides a stable programmatic interface used by the TUI and the Emacs frontend. The CLI communicates using JSON on stdout for structured commands and returns non-zero exit codes on error. Long outputs (logs) are written to a file and `{"out_path": "/path/to/file"}` is returned when appropriate.

Design principles
- Small API surface: only commands required by UI and automation.
- Deterministic JSON outputs with `status`, `code`, `msg`, and optional `data` fields.
- Preserve human readable output on stderr for operators.

Global options
- --host <spec>  # user@host[:port] or local
- --dry-run      # do not perform changes, only show planned commands
- --as-root      # run privileged subcommands via sudo/polkit (UI must confirm)

Base JSON response format
```
{
  "status": "ok" | "error",
  "code": 0,            # 0 for success, non-zero for specific errors
  "msg": "human readable summary",
  "data": { ... }       # optional structured data
}
```

Commands

1) list-services
Usage: proctl list-services --host <spec>
Output: data.services = [{name, description, active, enabled}]

2) service-action
Usage: proctl service-action --host <spec> --service <name> --action start|stop|restart|status
Output: usual JSON with data.output (path to logfile) if long.

3) run-script
Usage: proctl run-script --host <spec> --script <name> [--args '...'] [--dry-run] [--as-root]
Purpose: run named scripts shipped in `scripts/` by name.

4) upload-file
Usage: proctl upload-file --host <spec> --src <local-path> --dst <remote-path> [--as-root]
Behavior: uploads file via scp; creates a timestamped backup of dst if exists. Returns data.backup = "/var/lib/pro-nix/backups/...." and data.dst

5) restore-backup
Usage: proctl restore-backup --host <spec> --backup <path> [--as-root]
Behavior: restore backup to original path; returns status JSON and log path.

6) check-join-secret
Usage: proctl check-join-secret --host <spec> --secret-file <local-path>
Behavior: opens secret file and verifies structure, returns status and data.valid = true|false and data.reason.

7) set-join-secret
Usage: proctl set-join-secret --host <spec> --secret-file <local-path> [--as-root]
Behavior: uploads secret to /etc/pro-peer/join-secret.json with secure perms; returns data.backup.

8) list-ifaces
Usage: proctl list-ifaces --host <spec>
Output: data.ifaces = [{name, ip4, ip6, state}]

9) enable-discovery
Usage: proctl enable-discovery --host <spec> --iface <name> [--dry-run] [--as-root]
Behavior: places Avahi service file and restarts avahi-daemon on the host; returns data.service_file and data.backup.

10) exec
Usage: proctl exec --host <spec> --cmd "..." [--as-root] [--dry-run]
Behavior: executes arbitrary command on host via ssh (or locally), writes stdout/stderr to a log file and returns path.

Audit log
- proctl appends JSONL records to ~/.local/share/pro-nix/actions.log with fields:
  timestamp, user, host, action, cmd_preview, dry_run, result_code, out_path

Errors
- All non-successful actions should return status="error" and code != 0 with diagnostic msg in msg and optional data.error_details.
