#!/usr/bin/env bash
# tests/contract/pro-ssh-keys-01.sh
#
# Контракт: SSH-ключи для az/za/la/bo задаются через опцию
# `pro.ssh.authorizedKeys` (default = [ ]); ключи попадают в
# `~/.ssh/authorized_keys` каждого аккаунта; пример задокументирован в
# `local.nix.example`; `local.nix` (куда пользователь кладёт ключи) — в
# `.gitignore`, а `local.nix.example` (документация) — НЕ в `.gitignore`
# (распространённый регресс: оба файла в .gitignore, шаблон случайно
# не коммитится).
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"

f_users="$root/modules/pro-users.nix"
f_example="$root/local.nix.example"
f_gitignore="$root/.gitignore"

for f in "$f_users" "$f_example" "$f_gitignore"; do
  [ -e "$f" ] || { echo "FAIL: missing file $f" >&2; exit 1; }
done

ok=0
fail() { echo "FAIL: $*" >&2; exit 1; }

# 1) Опция `pro.ssh.authorizedKeys` объявлена в pro-users.nix
echo -n "01 pro-users.nix: \`pro.ssh.authorizedKeys\` option declared… "
if ! rg -qU 'options\.pro\.ssh\.authorizedKeys\s*=\s*lib\.mkOption' "$f_users"; then
  fail "нет \`pro.ssh.authorizedKeys = lib.mkOption { ... }\` в pro-users.nix"
fi
ok=$((ok+1)); echo "ok"

# 2) Default — пустой список (default false, иначе ломаем существующие хосты)
echo -n "02 pro-users.nix: default = [ ] (без ключей ssh не работает — by design)… "
if ! rg -qU 'options\.pro\.ssh\.authorizedKeys\s*=\s*lib\.mkOption\s*\{[\s\S]*?default\s*=\s*\[\s*\]' "$f_users"; then
  fail "default не \`[ ]\`; пустой default сохраняет текущее поведение (нет ключей → нет ssh-логина)"
fi
ok=$((ok+1)); echo "ok"

# 3) Ключи потребляются в `users.users.<name>.openssh.authorizedKeys.keys`
echo -n "03 pro-users.nix: keys wired to users.users.<name>.openssh.authorizedKeys… "
if ! rg -q 'openssh\.authorizedKeys\.keys\s*=\s*config\.pro\.ssh\.authorizedKeys' "$f_users"; then
  fail "нет \`openssh.authorizedKeys.keys = config.pro.ssh.authorizedKeys\`"
fi
ok=$((ok+1)); echo "ok"

# 4) local.nix.example документирует опцию
echo -n "04 local.nix.example: \`pro.ssh.authorizedKeys\` documented… "
if ! rg -q 'pro\.ssh\.authorizedKeys' "$f_example"; then
  fail "local.nix.example не упоминает pro.ssh.authorizedKeys — оператор не узнает про опцию"
fi
ok=$((ok+1)); echo "ok"

# 5) local.nix в .gitignore (защита от случайного коммита секретов)
echo -n "05 .gitignore: \`local.nix\` ignored (secrets)… "
if ! rg -q '^/?local\.nix\s*$' "$f_gitignore"; then
  fail "local.nix не в .gitignore — коммит ключей в публичный репо"
fi
ok=$((ok+1)); echo "ok"

# 6) local.nix.example НЕ в .gitignore (распространённый регресс)
echo -n "06 .gitignore: \`local.nix.example\` NOT ignored (template must commit)… "
if rg -q '^\s*local\.nix\.example\s*$' "$f_gitignore"; then
  fail "local.nix.example в .gitignore — шаблон не коммитится, документация теряется"
fi
ok=$((ok+1)); echo "ok"

# 7) users.users.<name> для az/za/la/bo существуют (4 аккаунта)
echo -n "07 pro-users.nix: 4 accounts (az/za/la/bo) declared… "
for name in az za la bo; do
  if ! rg -q "\"?$name\"?" "$f_users"; then
    fail "нет декларации пользователя \`$name\`"
  fi
done
ok=$((ok+1)); echo "ok"

echo
echo "pro-ssh-keys contract: $ok/7 checks passed"
