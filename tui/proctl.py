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
    d = Path(__file__).resolve().parent.parent / 'scripts' / 'run-samba-diagnostics.sh'
    if d.exists():
        import subprocess
        p = subprocess.run([str(d)], capture_output=True, text=True)
        print(p.stdout)
        if p.stderr:
            print('ERR:'+p.stderr, file=sys.stderr)
    else:
        print('no diagnostics script found', file=sys.stderr)


def main():
    if len(sys.argv) < 2:
        print('usage: proctl.py <cmd>')
        sys.exit(2)
    cmd = sys.argv[1]
    if cmd == 'list-ifaces':
        list_ifaces()
    elif cmd == 'diagnostics':
        diagnostics()
    else:
        print('unknown command', file=sys.stderr)
        sys.exit(2)


if __name__ == '__main__':
    main()
