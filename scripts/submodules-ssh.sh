#!/usr/bin/env bash
set -euo pipefail

# Script: scripts/submodules-ssh.sh
# Преобразовать все HTTPS-субмодули в SSH, используя те же user/org, что в .gitmodules

GITMODULES=".gitmodules"
BACKUP=".gitmodules.backup.$(date +%s)"

if [ ! -f "$GITMODULES" ]; then
  echo "Error: $GITMODULES not found" >&2
  exit 1
fi

echo "Backup: $GITMODULES → $BACKUP"
cp "$GITMODULES" "$BACKUP"

trap 'echo "Восстановление из $BACKUP"; cp "$BACKUP" "$GITMODULES"; rm "$BACKUP"; exit 1' EXIT

process_url() {
  case "$1" in
    https://github.com/*/*)
      owner="${1#https://github.com/}"
      owner="${owner%%/*}"
      repo="${1##*/}"
      repo="${repo%.git}"
      printf 'git@github.com:%s/%s.git\n' "$owner" "$repo"
      ;;
    https://codeberg.org/*/*)
      owner="${1#https://codeberg.org/}"
      owner="${owner%%/*}"
      repo="${1##*/}"
      repo="${repo%.git}"
      printf 'git@codeberg.org:%s/%s.git\n' "$owner" "$repo"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

echo "Преобразование .gitmodules URL"

while IFS=' ' read -r key url; do
  [ -n "$key" ] || continue
  new_url=$(process_url "$url")
  if [ "$url" != "$new_url" ]; then
    echo "  $url → $new_url"
    git config -f "$GITMODULES" "$key" "$new_url"
  fi
done < <(git config -f "$GITMODULES" --get-regexp '^submodule\..*\.url$' | awk '{print $1, $2}')

# Обновляем субмодули до новых URL'ов
echo "Обновление субмодулей до SSH"
git submodule sync --recursive

git submodule update --remote --merge

echo "✓ Все субмодули теперь используют SSH"

echo "Использование"
echo "  ./scripts/submodules-ssh.sh   # изменить на SSH"
echo ""
echo "Чтобы вернуться к HTTPS:"
echo "  cp .gitmodules.backup.$(date +%s) .gitmodules"
echo "  git submodule sync && git submodule update --remote --merge"

trap - EXIT
