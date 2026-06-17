#!/usr/bin/env bash

# Отчётный скрипт: проверяет доступные способы подключения к приватным каналам
# (Tor, I2P и прочие) и печатает красивый отчёт на русском.
# Запускайте: bash scripts/check_privacy_proxies.sh

set -euo pipefail
IFS=$'\n\t'

timestamp() { date +"%F %T"; }

# Helpers
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
print_h(){ printf "\n== %s ==\n" "$1"; }
ok(){ printf "[ OK ] %s\n" "$1"; }
warn(){ printf "[???] %s\n" "$1"; }
err(){ printf "[ERR] %s\n" "$1"; }

# Test TCP connect using /dev/tcp (fallback to nc)
tcp_check(){
  host=$1; port=$2; timeout=${3:-1}
  if has_cmd nc; then
    nc -z -w $timeout "$host" "$port" >/dev/null 2>&1 && return 0 || return 1
  else
    # /dev/tcp may block; use timeout builtin if available
    (</dev/tcp/"$host"/"$port") >/dev/null 2>&1 && return 0 || return 1
  fi
}

# Gather basic network info
HOSTNAME=$(hostname -f 2>/dev/null || hostname)
DATE=$(timestamp)

print_h "Сводка (кратко)"
cat <<EOF
Хост: $HOSTNAME
Время: $DATE
Скрипт проверяет:
 - локальные демоны/байнари: tor, i2pd/i2p, tailscale, zerotier, openvpn, wireguard
 - прослушивающие прокси-порты (SOCKS/HTTP): 9050/9150/8118 (Tor), 4444/4447/7657 (I2P) и т.п.
 - доступность прокси на шлюзе (полезно при использовании Android/Orbot как хотспота)
 - установленные инструменты: torsocks, proxychains, redsocks

Результат: ниже — детальная проверка и рекомендации.
EOF

print_h "1) Наличие ключевых утилит"
TOOLS=(tor torsocks proxychains proxychains4 i2pd i2p tailscale zerotier-one wg wg-quick openvpn socat redsocks)
for t in "${TOOLS[@]}"; do
  if has_cmd "$t"; then
    ok "$t — найден ($(command -v $t))"
  else
    warn "$t — не найден"
  fi
done

print_h "2) Системные службы (systemd)"
if has_cmd systemctl; then
  for svc in tor tor@default i2pd tailscaled zerotier-one openvpn@client; do
    if systemctl list-units --type=service --all | rg -i "^${svc}" >/dev/null 2>&1; then
      state=$(systemctl is-active "$svc" 2>/dev/null || echo inactive)
      ok "$svc — сервис есть, состояние: $state"
    else
      warn "$svc — сервис не найден"
    fi
  done
else
  warn "systemctl недоступен — пропускаем проверку сервисов"
fi

print_h "3) Локальные прослушивающие SOCKS/HTTP порты (локальная машина)"
# common ports to check: tor: 9050,9150 socks; 8118 http; i2p: 4444 http, 4447 socks, 7657 console; wireguard: tun interface
PORTS=("127.0.0.1:9050" "127.0.0.1:9150" "127.0.0.1:8118" "127.0.0.1:4444" "127.0.0.1:4447" "127.0.0.1:7657")
if has_cmd ss; then
  ss -ltnp | sed -n '1,200p'
elif has_cmd netstat; then
  netstat -ltnp | sed -n '1,200p'
else
  echo "Не удалось показать список прослушивающих портов (нет ss/netstat)"
fi

for p in "${PORTS[@]}"; do
  host=${p%%:*}
  port=${p##*:}
  if tcp_check "$host" "$port" 1; then
    ok "Порт $host:$port — доступен (возможно соответствующий прокси)"
  else
    warn "Порт $host:$port — недоступен"
  fi
done

print_h "4) Проверка шлюза / соседнего хоста (полезно при Android-hotspt)"
# default gateway
GW=$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')
if [ -n "$GW" ]; then
  ok "Default gateway: $GW"
  # check common proxy ports on gateway
  REMOTE_PORTS=(9050 9150 8118 9051 4444 4447)
  for pr in "${REMOTE_PORTS[@]}"; do
    if tcp_check "$GW" "$pr" 1; then
      ok "Gateway $GW порт $pr — открыт (возможно Orbot/I2P доступны на нём)"
    else
      warn "Gateway $GW порт $pr — закрыт/недоступен"
    fi
  done
else
  warn "Не найден default gateway"
fi

print_h "5) Интерфейсы и VPN/TUN"
ip -brief addr || true

if ip link show tun0 >/dev/null 2>&1; then ok "tun0 — есть (возможно VPN)"; else warn "tun0 — нет"; fi
if ip link show wg0 >/dev/null 2>&1; then ok "wg0 — есть (WireGuard)"; else warn "wg0 — нет"; fi

print_h "6) Переменные окружения proxy"
env | rg -i "proxy" -n || echo "(нет переменных proxy в окружении)"

print_h "7) Инструменты для проброса всего трафика через SOCKS/HTTP"
TOOLS2=(proxychains torsocks redsocks socat)
for t in "${TOOLS2[@]}"; do
  if has_cmd "$t"; then ok "$t — доступен"; else warn "$t — не найден"; fi
done

print_h "8) Рекомендации (диалектический анализ и варианты)"
cat <<'ANALYSIS'
Цель: "Все запросы из компьютера идут через Tor (или I2P/прочие)".

1) Возможности и ограничения:
 - Tor (SOCKS) транслирует TCP (HTTP/HTTPS) трафик, но не все приложения автоматически используют SOCKS.
 - DNS-запросы по умолчанию могут идти в обход — нужно использовать 'socks5h' или forcе проксирование DNS.
 - UDP (VoIP, DNS over UDP, некоторые игры) не поддерживается Tor.
- I2P предоставляет HTTP/SOCKS прокси для доступа к eepsites и сервисам внутри I2P; не заменяет весь Интернет.

2) Варианты реализации "всё через прокси":
 A) Перезапуск приложений через torsocks/proxychains (простой, per-app).
 B) Установка переменных окружения (http_proxy, all_proxy) — работает лишь для программ, читающих их.
 C) Transparent proxy: использовать iptables/nftables + redsocks/socat чтобы принудительно перенаправлять весь TCP на SOCKS — более сложный, требует root.
 D) Использовать полноценный VPN: если Orbot на Android поддерживает VPN-over-Tor, или поднять VPN-сервер поверх Tor (нетривиально).
 E) Для VPN-интерфейсов (tun/wg) — маршрутизация на уровне IP позволяет прозрачно пропускать трафик через них.

3) Практические рекомендации:
 - Для простой работы: используйте torsocks/proxychains для тех приложений, которые вы хотите защитить.
 - Если нужен системный proxy для упрощения — выставьте переменные окружения в вашей сессии/менеджере отображения.
 - Для "всего трафика" — разверните transparent proxy (redsocks + iptables) или используйте виртуальную машину с настройкой прокси.
 - Проверяйте DNS (используйте dns over https/tor-resolving или proxy-aware resolver).

ANALYSIS

print_h "Конец отчёта"

# exit 0
