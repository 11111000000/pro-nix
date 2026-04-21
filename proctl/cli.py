#!/usr/bin/env python3
"""proctl - thin CLI wrapper used by TUI and Emacs UI prototypes.

This prototype exposes minimal commands used by the UI: run-script and exec.
It is intentionally small and uses subprocess to call existing scripts under
scripts/ directory.
"""
import sys, os, json, subprocess

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SCRIPTS = os.path.join(ROOT, 'scripts')

def run_script(name):
    path = os.path.join(SCRIPTS, name)
    if not os.path.exists(path):
        # try with .sh
        if os.path.exists(path + '.sh'):
            path = path + '.sh'
        else:
            return {'ok': False, 'error': 'script not found', 'path': path}
    p = subprocess.run([path], capture_output=True, text=True)
    return {'ok': p.returncode == 0, 'rc': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr}

def exec_cmd(cmd, as_root=False, dry=False):
    if dry:
        return {'ok': True, 'cmd': cmd, 'dry': True}
    if as_root:
        cmd = ['sudo', '--'] + cmd
    p = subprocess.run(cmd, capture_output=True, text=True)
    return {'ok': p.returncode == 0, 'rc': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr}

def main(argv):
    if len(argv) < 2:
        print(json.dumps({'ok': False, 'error': 'no command'}))
        return 2
    cmd = argv[1]
    if cmd == 'run-script':
        if len(argv) < 3:
            print(json.dumps({'ok': False, 'error': 'missing script name'}))
            return 2
        res = run_script(argv[2])
        print(json.dumps(res))
        return 0 if res.get('ok') else 1
    if cmd == 'exec':
        # rest are command parts
        as_root = '--as-root' in argv
        dry = '--dry' in argv
        parts = [a for a in argv[2:] if a not in ('--as-root','--dry')]
        if not parts:
            print(json.dumps({'ok': False, 'error': 'no command parts'}))
            return 2
        res = exec_cmd(parts, as_root=as_root, dry=dry)
        print(json.dumps(res))
        return 0 if res.get('ok') else 1
    print(json.dumps({'ok': False, 'error': 'unknown command'}))
    return 2

if __name__ == '__main__':
    sys.exit(main(sys.argv))
