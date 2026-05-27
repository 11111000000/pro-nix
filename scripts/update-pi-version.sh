#!/usr/bin/env bash
# Безопасный помощник для обновления `pi` input в pro-nix
# По умолчанию: dry-run — не изменяет файлы.
# Usage: ./scripts/update-pi-version.sh [version|latest] [--apply]
# Пример: ./scripts/update-pi-version.sh latest
# Если передать --apply, скрипт сам обновит flake.lock и создаст коммит.

set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "Требуется curl" >&2; exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Требуется jq" >&2; exit 2
fi
if ! command -v nix-prefetch-url >/dev/null 2>&1; then
  echo "Требуется nix-prefetch-url" >&2; exit 2
fi

ARG=${1:-latest}
APPLY=false
for a in "${@:2}"; do
  if [ "$a" = "--apply" ]; then APPLY=true; fi
done

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

base_url_prefix="https://github.com/badlogic/pi-mono/releases/download/v"
asset_name="pi-linux-x64.tar.gz"

if [ "$ARG" = "latest" ]; then
  echo "Запрашиваю latest release tag у GitHub..."
  tag=$(curl -sSfL "https://api.github.com/repos/badlogic/pi-mono/releases/latest" | jq -r '.tag_name') || {
    echo "Не удалось получить latest release" >&2; exit 3
  }
  version=${tag#v}
else
  version="$ARG"
fi

url="${base_url_prefix}${version}/${asset_name}"
echo "Версия: $version"
echo "Asset URL: $url"

echo "Вычисляю narHash (nix-prefetch-url --unpack)..."
sha=$(nix-prefetch-url --unpack "$url" 2>/dev/null) || {
  echo "Не удалось получить narHash для $url" >&2
  exit 4
}

echo "narHash: $sha"

timestamp=$(date +%s)

cat <<EOF

Dry-run: предлагаемые шаги для вручнуюcкого обновления flake.lock:

1) Обновить `flake.lock` node `pi`:
   - rev = "$version";
   - lastModified = $timestamp;
   - narHash = "$sha";

2) Проверить diff:
   git --no-pager diff -- flake.lock || true

3) Зафиксировать изменения:
   git add flake.lock
   git commit -m "chore: update pi input to v${version}"

EOF

if [ "$APPLY" = true ]; then
  python3 - "$version" "$timestamp" "$sha" <<'PY'
import json
import sys
from pathlib import Path

version, timestamp, nar_hash = sys.argv[1:4]
lock = json.loads(Path("flake.lock").read_text())
node = lock["nodes"]["pi"]
node["locked"]["lastModified"] = int(timestamp)
node["locked"]["narHash"] = nar_hash
node["locked"]["rev"] = version
Path("flake.lock").write_text(json.dumps(lock, indent=2) + "\n")
PY
  git add flake.lock
  git commit -m "chore: update pi input to v${version}"
  echo "flake.lock updated and committed." >&2
fi

echo "Готово (dry-run)."
