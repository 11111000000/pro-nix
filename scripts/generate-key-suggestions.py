#!/usr/bin/env python3
"""Generate key suggestions by parsing pro/register-module-keys forms.

This parses .el files under emacs/base/modules and extracts pairs like
("C-c x" . command) from pro/register-module-keys calls.
"""
import sys, os, re

def extract_sexps(text):
    # find positions of "(pro/register-module-keys"
    results = []
    for m in re.finditer(r"\(pro/register-module-keys", text):
        start = m.start()
        # find balanced sexp
        depth = 0
        i = start
        L = len(text)
        while i < L:
            c = text[i]
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    results.append(text[start:i+1])
                    break
            i += 1
    return results

def parse_sexp(sexp):
    # minimal parse: find module name and pairs
    # remove newlines for simpler regex
    s = ' '.join(sexp.split())
    # module: after pro/register-module-keys possibly ' or not
    m = re.search(r"pro/register-module-keys\s+'?([^\s(]+)", s)
    module = m.group(1) if m else 'unknown'
    pairs = re.findall(r'\("([^\"]+)"\s*\.\s*([^\s()]+)\)', s)
    return module, pairs

def main(repo_root, out_path):
    mod_dir = os.path.join(repo_root, 'emacs', 'base', 'modules')
    entries = []
    if not os.path.isdir(mod_dir):
        print('modules dir not found', file=sys.stderr)
        return 1
    for fname in sorted(os.listdir(mod_dir)):
        if not fname.endswith('.el'):
            continue
        path = os.path.join(mod_dir, fname)
        try:
            with open(path, 'r', encoding='utf-8') as f:
                text = f.read()
        except Exception:
            continue
        sexps = extract_sexps(text)
        for sexp in sexps:
            module, pairs = parse_sexp(sexp)
            if pairs:
                entries.append((module, pairs))
    # write out
    with open(out_path, 'w', encoding='utf-8') as out:
        out.write('# Generated suggestions\n\n')
        for module, pairs in entries:
            out.write(f"# PRO-MODULE: {module}\n")
            for k, cmd in pairs:
                out.write(f"| Suggested | {k} | {cmd} | suggested from {module} |\n")
            out.write('\n')
    return 0

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('Usage: generate-key-suggestions.py REPO_ROOT OUT_FILE', file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
