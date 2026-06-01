#!/usr/bin/env bash
# Утилита для управления экспортом переменных proxy для сессии
# Usage:
#  ./scripts/privacy_env.sh enable HOST:PORT   - создаёт ~/.privacy_proxy_env и печатает команду для source
#  ./scripts/privacy_env.sh print HOST:PORT    - печатает export-строки в stdout (для eval)
#  ./scripts/privacy_env.sh disable            - удаляет ~/.privacy_proxy_env
#  ./scripts/privacy_env.sh show               - показывает текущий файл

set -euo pipefail
file="$HOME/.privacy_proxy_env"

print_exports(){
  hostport="$1"
  # assume socks5
  echo "export ALL_PROXY=\"socks5h://$hostport\""
  echo "export all_proxy=\"socks5h://$hostport\""
  echo "export HTTP_PROXY=\"http://$hostport\""
  echo "export http_proxy=\"http://$hostport\""
  echo "export HTTPS_PROXY=\"http://$hostport\""
  echo "export https_proxy=\"http://$hostport\""
  echo "# Для git: git config --global http.proxy \"socks5h://$hostport\""
}

case "${1:-}" in
  enable)
    if [ -z "${2:-}" ]; then echo "Usage: $0 enable HOST:PORT" >&2; exit 2; fi
    hostport="$2"
    cat > "$file" <<EOF
# Файл с переменными proxy (сгенерирован scripts/privacy_env.sh)
$(print_exports "$hostport")
EOF
    chmod 600 "$file"
    echo "Создан $file"
    echo "Чтобы применить в текущей сессии: source $file"
    echo "Или выполнить в одном шаге: eval \"$(printf '%q' "$(print_exports "$hostport")")\""
    ;;
  print)
    if [ -z "${2:-}" ]; then echo "Usage: $0 print HOST:PORT" >&2; exit 2; fi
    print_exports "$2" ;;
  disable)
    if [ -f "$file" ]; then rm -f "$file" && echo "Удалён $file"; else echo "Файла $file нет"; fi ;;
  show)
    if [ -f "$file" ]; then echo "--- $file ---" && sed -n '1,200p' "$file"; else echo "Файла $file нет"; fi ;;
  *)
    echo "Usage: $0 {enable HOST:PORT | print HOST:PORT | disable | show}" >&2
    exit 2
    ;;
esac
