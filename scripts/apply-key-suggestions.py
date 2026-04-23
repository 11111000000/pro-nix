#!/usr/bin/env python3
"""Apply suggested keys from suggestions file into emacs-keys.org.
Usage: scripts/apply-key-suggestions.py SUGGESTIONS_FILE REPO_ROOT
"""
import sys, os, re

def parse_suggestions(path):
    pairs = []
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            m = re.match(r"\|\s*Suggested\s*\|\s*([^|]+)\|\s*([^|]+)\|", line)
            if m:
                key = m.group(1).strip()
                cmd = m.group(2).strip()
                pairs.append((key, cmd, line.rstrip()))
    return pairs

def exists_in_keys(keys_path, key, cmd):
    with open(keys_path, 'r', encoding='utf-8') as f:
        for line in f:
            if key in line and cmd in line:
                return True
    return False

def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    sug = sys.argv[1]
    repo = sys.argv[2]
    keys_file = os.path.join(repo, 'emacs-keys.org')
    if not os.path.exists(sug):
        print('Suggestions file not found:', sug, file=sys.stderr)
        return 3
    if not os.path.exists(keys_file):
        print('Keys file not found:', keys_file, file=sys.stderr)
        return 4
    backup = keys_file + '.bak.' + __import__('time').strftime('%Y%m%d%H%M%S')
    import shutil
    shutil.copyfile(keys_file, backup)
    print('Backup created:', backup)
    pairs = parse_suggestions(sug)
    if not pairs:
        print('No suggestions found in', sug)
        return 0
    with open(keys_file, 'a', encoding='utf-8') as out:
        out.write('\n')
        out.write('# AUTO-MERGED: ' + __import__('time').ctime() + '\n')
        added = 0
        for key, cmd, raw in pairs:
            if exists_in_keys(keys_file, key, cmd):
                print('Skipping existing:', key, cmd)
                continue
            out.write(raw + '\n')
            print('Added:', key, cmd)
            added += 1
    if added > 0:
        # git commit
        import subprocess
        subprocess.run(['git', 'add', keys_file], check=False)
        subprocess.run(['git', 'commit', '-m', 'chore(keys): auto-merge module suggestions into emacs-keys.org'], check=False)
    else:
        print('No new suggestions to add')
    return 0

if __name__ == '__main__':
    sys.exit(main())
