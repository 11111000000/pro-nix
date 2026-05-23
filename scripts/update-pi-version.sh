#!/usr/bin/env bash
# Безопасный помощник для обновления pi в pro-nix
# По умолчанию: dry-run — не изменяет файлы.
# Usage: ./scripts/update-pi-version.sh [version|latest] [--apply]
# Пример: ./scripts/update-pi-version.sh latest
# Если передать --apply, скрипт выдаст команды, которые нужно вручную выполнить (не производит автоматического коммита).

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

echo "Вычисляю sha256 (nix-prefetch-url --unpack)..."
sha=$(nix-prefetch-url --unpack "$url" 2>/dev/null) || {
  echo "Не удалось получить sha256 для $url" >&2
  exit 4
}

echo "sha256: $sha"

cat <<EOF

Dry-run: предлагаемые шаги для вручнуюcкого обновления system-packages.nix:

1) Сделать бэкап текущего файла (уже рекомендуется):
   cp system-packages.nix system-packages.nix.bak

2) Внести изменения в блок, где описан pi-coding-agent:
   - обновить version = "$version";
   - обновить sha256 = "$sha";

Если вы используете sed/perl, примерная команда (внимание: проверяйте diff перед коммитом):

# Пример: заменить version
perl -0777 -pe "s/(pname\s*=\s*\"pi-coding-agent\";.*?version\s*=\s*\")[^\"]*(\")/\1${version}\2/gs" system-packages.nix > system-packages.nix.new
# Пример: заменить sha256
perl -0777 -pe "s/(pname\s*=\s*\"pi-coding-agent\";.*?sha256\s*=\s*\")[^\"]*(\")/\1${sha}\2/gs" system-packages.nix.new > system-packages.nix.updated

# Посмотреть diff
git --no-pager diff -- system-packages.nix system-packages.nix.updated || true

# После проверки выполнить замещение и коммит
mv system-packages.nix.updated system-packages.nix
git add system-packages.nix
git commit -m "chore: update pi-coding-agent to v${version} (sha256: ${sha})"

EOF

if [ "$APPLY" = true ]; then
  echo "--apply указан: скрипт не станет автоматически вносить правки, но вы можете выполнить предложенные команды вручную." >&2
fi

echo "Готово (dry-run)."