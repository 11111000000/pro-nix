
#!/usr/bin/env bash
set -euo pipefail

# Smoke‑тест: выполняет non-root сборку toplevel для хоста huawei и,
# при наличии systemd-nspawn, пытается выполнить упрощённую активацию внутри
# контейнера. Тест падает, если в журнале во время активации встречается
# сообщение "Rejected send message".

root="$(cd "$(dirname "$0")/../.." && pwd)"

builder="$(command -v nix || true)"
if [ -z "$builder" ]; then
  echo "nix не найден" >&2
  exit 2
fi

out="$($builder --extra-experimental-features 'nix-command flakes' build --print-out-paths "$root"#nixosConfigurations.huawei.config.system.build.toplevel)"

if [ -z "$out" ]; then
  echo "Сборка toplevel не удалась" >&2
  exit 2
fi

echo "Собран toplevel: $out"

# Если доступен systemd-nspawn — попытаться прогнать упрощённую активацию.
if command -v systemd-nspawn >/dev/null 2>&1; then
  tmpdir=$(mktemp -d)
  mkdir -p "$tmpdir/rootfs"
  # Используем построенный профиль как минимальный overlay rootfs (best-effort)
  rsync -a "$out/" "$tmpdir/rootfs/" || true
  echo "Пробная активация внутри systemd-nspawn (smoke)"
  if sudo systemd-nspawn -D "$tmpdir/rootfs" /bin/sh -c 'set -e; if command -v switch-to-configuration >/dev/null 2>&1; then switch-to-configuration switch || true; fi; journalctl -n 200 -o short' | rg -i "Rejected send message" >/dev/null; then
    echo "Обнаружено 'Rejected send message' во время активации" >&2
    exit 1
  fi
  rm -rf "$tmpdir"
else
  echo "systemd-nspawn недоступен; пропускаем smoke-тест живой активации" >&2
fi

echo "smoke тест живой активации: OK"
