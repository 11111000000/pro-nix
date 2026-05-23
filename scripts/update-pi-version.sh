#!/usr/bin/env bash
# Обновить версию pi (pi-coding-agent) в system-packages.nix
# Usage: ./scripts/update-pi-version.sh [version|latest] [--commit]
# Пример: ./scripts/update-pi-version.sh latest --commit

set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

FILE="system-packages.nix"
if [ ! -f "$FILE" ]; then
  echo "Ошибка: $FILE не найден в корне репозитория. Выполните скрипт из корня репо." >&2
  exit 2
fi

ARG=${1:-latest}
COMMIT=false
if [ "${2:-}" = "--commit" ] || [ "${3:-}" = "--commit" ]; then
  COMMIT=true
fi

# Пример URL: https://github.com/badlogic/pi-mono/releases/download/v0.73.0/pi-linux-x64.tar.gz
base_url_prefix="https://github.com/badlogic/pi-mono/releases/download/v"
asset_name="pi-linux-x64.tar.gz"

check_deps() {
  for cmd in curl jq nix-prefetch-url perl git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Требуется команда: $cmd" >&2
      exit 3
    fi
  done
}

check_deps

if [ "$ARG" = "latest" ]; then
  echo "Запрашиваю latest release tag у GitHub..."
  tag=$(curl -sSfL "https://api.github.com/repos/badlogic/pi-mono/releases/latest" | jq -r '.tag_name') || {
    echo "Не удалось получить latest release из GitHub. Можно указать версию вручную." >&2
    exit 4
  }
  # strip leading v if present
  version=${tag#v}
else
  version="$ARG"
fi

echo "Выбрана версия: $version"
url="${base_url_prefix}${version}/${asset_name}"

echo "Пробую скачать и вычислить sha256 (nix-prefetch-url --unpack)..."
sha=""
set +e
sha=$(nix-prefetch-url --unpack "$url" 2>/dev/null) || rc=$?
set -e
if [ -z "${sha:-}" ]; then
  echo "Не удалось получить sha256 для $url" >&2
  echo "Проверьте, существует ли релиз и доступен ли asset: $url" >&2
  exit 5
fi

echo "Найден sha256: $sha"

# Сделать бэкап
cp -v "$FILE" "$FILE.bak"

# Обновить version и sha256 в блоке с pi-coding-agent
perl -0777 -pe '
  my $v = shift @ARGV; my $s = shift @ARGV;
  # Обновить version внутри блока, где есть pname = "pi-coding-agent";
  s/(pname\s*=\s*"pi-coding-agent";.*?version\s*=\s*")([^\"]*)(")/"$1".$v."$3"/gs;
  s/(pname\s*=\s*"pi-coding-agent";.*?sha256\s*=\s*")([^\"]*)(")/"$1".$s."$3"/gs;
' "$version" "$sha" "$FILE" > "$FILE.tmp" || { echo "Не удалось обновить $FILE" >&2; mv "$FILE.bak" "$FILE"; exit 6; }

mv "$FILE.tmp" "$FILE"
chmod --reference="$FILE.bak" "$FILE" || true

echo "Файл $FILE обновлён. (бэкап: $FILE.bak)"

if [ "$COMMIT" = true ]; then
  git add "$FILE"
  git commit -m "chore: update pi-coding-agent to v${version} (sha256: ${sha})" || {
    echo "git commit не удался. Проверьте статус git." >&2
  }
  echo "Изменения закоммичены в локальный репозиторий. Не забудьте открыть PR/Push." 
else
  echo "Изменения не закоммичены. Если всё OK, выполните:"
  echo "  git add $FILE && git commit -m 'chore: update pi-coding-agent to v${version}'"
fi

# Инструкции по проверке
cat <<EOF
Дальнейшие шаги для проверки (рекомендуется):
1) Оценить вычислимость пакетов/сборку целевого артефакта (не полный host):
   nix --extra-experimental-features 'nix-command flakes' eval --json '.#nixosConfigurations.huawei.config.environment.systemPackages' | jq -r '.[] | select(test("pi-coding-agent"))'
   # или, если хотите собрать host (тяжеловато):
   # nix build .#nixosConfigurations.huawei.config.system.build.toplevel

2) Получить путь пакета и запустить smoke-test:
   pi_pkg=$(nix --extra-experimental-features 'nix-command flakes' eval --json '.#nixosConfigurations.huawei.config.environment.systemPackages' | jq -r '.[] | select(test("pi-coding-agent"))' | head -n1)
   bash -x "\$pi_pkg/bin/pi" --help || \ 
   # если wrapper требует loader, запустите явно через glibc loader (в devshell или замените путь):
   # ${pkgs_placeholder}/lib/ld-linux-x86-64.so.2 "\$pi_pkg/libexec/pi-coding-agent/pi" --help

3) Запустите ./tools/surface-lint.sh и (опционально) tests/contract

EOF

echo "Готово." 
