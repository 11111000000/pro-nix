#!/usr/bin/env python3
"""Minimal proctl shim for prototype TUI.

Provides tiny wrappers for commands used by the TUI prototype.
"""
import json
import sys
from pathlib import Path


def list_ifaces():
    # best-effort using ip command
    import subprocess
    p = subprocess.run(['ip', '-4', 'addr', 'show'], capture_output=True, text=True)
    print(p.stdout)


def diagnostics():
    # call the repo diagnostic script if present
    # Provide a clear, deterministic diagnostics output for the prototype.
    # If a real diagnostics script is available in scripts/, run it; otherwise
    # emit a synthetic, user-friendly report so the UI shows something.
    d = Path(__file__).resolve().parent.parent / 'scripts' / 'run-samba-diagnostics.sh'
    if d.exists():
        import subprocess
        p = subprocess.run([str(d)], capture_output=True, text=True)
        print(p.stdout)
        if p.stderr:
            print('ERR:'+p.stderr, file=sys.stderr)
    else:
        # Synthetic diagnostics
        info = {
            'hostname': Path('/etc/hostname').read_text().strip() if Path('/etc/hostname').exists() else 'unknown',
            'os': sys.platform,
            'python': sys.version.splitlines()[0],
            'checks': {
                'network': 'ok' if Path('/proc/net/dev').exists() else 'missing',
                'samba_installed': 'unknown',
            }
        }
        print('Synthetic diagnostics (prototype):')
        print(json.dumps(info, indent=2))


def main():
    if len(sys.argv) < 2:
        print('usage: proctl.py <cmd>')
        sys.exit(2)
    cmd = sys.argv[1]
    if cmd == 'list-ifaces':
        list_ifaces()
    elif cmd == 'diagnostics':
        diagnostics()
    elif cmd == 'exec':
        # run arbitrary command for prototype purposes
        if len(sys.argv) < 3:
            print('usage: proctl.py exec <cmd> [args...]', file=sys.stderr)
            sys.exit(2)
        import subprocess
        p = subprocess.run(sys.argv[2:], capture_output=True, text=True)
        if p.stdout:
            print(p.stdout)
        if p.stderr:
            print(p.stderr, file=sys.stderr)
        sys.exit(p.returncode)
    else:
        print('unknown command', file=sys.stderr)
        sys.exit(2)


if __name__ == '__main__':
    main()
