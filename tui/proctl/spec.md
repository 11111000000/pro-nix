Proctl JSON CLI spec

This document specifies a minimal JSON-based CLI contract for proctl, the
backend command dispatcher used by TUI and Emacs frontends.

Commands are invoked as `proctl <command> [--json] [args...]` and return 0 on
success. When `--json` is given, output a single JSON object to stdout. For
long-running commands, proctl will stream logs to stdout and on completion may
print a final JSON summary line.

Commands

1. list-services
   - Description: list known managed services and their states
   - Usage: `proctl list-services --json`
   - Output: { "services": [{"name":"avahi-daemon","active":"active","enabled":true,"desc":"Avahi mDNS"}, ... ] }

2. service-action
   - Description: perform action on a service
   - Usage: `proctl service-action <name> <start|stop|restart|status> [--json]`
   - Output (json): { "name":"samba", "action":"restart", "result":"ok", "exit":0 }

3. run-script
   - Description: run a named script from scripts/ directory
   - Usage: `proctl run-script <script-name> [--args '...'] [--dry-run] [--json]`
   - Behavior: streams stdout/stderr; on completion returns JSON summary with path to log if large.

4. diagnostics
   - Description: run diagnostics script
   - Usage: `proctl diagnostics [--json]`
   - Output: { "bundle":"/path/to/log.tar.gz", "result":"ok" }

5. key-sync
   - Description: trigger pro-peer-sync-keys
   - Usage: `proctl key-sync [--json] [--dry-run]`

6. rebuild
   - Description: produce preview command for nixos-rebuild and optionally run
   - Usage: `proctl rebuild --preview` prints the command; `proctl rebuild --run` will attempt to run (may require sudo)

7. config-edit
   - Description: open a config in $EDITOR (frontend may launch editor)
   - Usage: `proctl config-edit <path>`

Errors
 - On failure, exit non-zero and output JSON error when --json given: { "error":"message" }
