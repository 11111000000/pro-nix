#!/usr/bin/env bash
# find_tor_proxy.sh
# Ищет рабочий Tor SOCKS/HTTP прокси среди локальных и gateway адресов.
# Выводит первую найденную подходящую запись в формате: TYPE HOST PORT (TYPE=socks|http)

set -euo pipefail
IFS=$'\n\t'

has_cmd(){ command -v "$1" >/dev/null 2>&1; }

# Basic tcp check
tcp_check(){ host=$1; port=$2; timeout=${3:-1};
  if has_cmd nc; then
    nc -z -w $timeout "$host" "$port" >/dev/null 2>&1 && return 0 || return 1
  else
    # try bash /dev/tcp (may fail on some shells)
    if (exec 3<>/dev/tcp/"$host"/"$port") >/dev/null 2>&1; then
      exec 3>&- 3<&- || true
      return 0
    else
      return 1
    fi
  fi
}

# Try using curl to check if proxy routes to Tor (check.torproject.org page contains 'Congratulations')
proxy_is_tor(){ type=$1; host=$2; port=$3; timeout=${4:-6}
  if ! has_cmd curl; then return 1; fi
  if [ "$type" = socks ]; then
    out=$(curl --socks5-hostname "$host:$port" -s --max-time $timeout https://check.torproject.org/ 2>/dev/null || true)
  else
    out=$(curl -x "http://$host:$port" -s --max-time $timeout https://check.torproject.org/ 2>/dev/null || true)
  fi
  if echo "$out" | rg -qi "congratulations" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# candidates: local common ports, plus gateway
GW=$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}' || true)
CAND=()
# local
CAND+=("socks 127.0.0.1 9050")
CAND+=("socks 127.0.0.1 9150")
CAND+=("http 127.0.0.1 8118")
# gateway
if [ -n "$GW" ]; then
  CAND+=("socks $GW 9050")
  CAND+=("socks $GW 9150")
  CAND+=("http $GW 8118")
fi

# additional: tor control port 9051 isn't proxy, skip

first_open=""
for c in "${CAND[@]}"; do
  # parse candidate with space delimiter regardless of global IFS
  oldIFS=$IFS; IFS=' '
  read -r type host port <<< "$c"
  IFS=$oldIFS
  if [ -z "${host:-}" ] || [ -z "${port:-}" ]; then
    continue
  fi
  if tcp_check "$host" "$port" 1; then
    # try to verify it's Tor using check.torproject.org if curl available
    if command -v curl >/dev/null 2>&1; then
      if proxy_is_tor "$type" "$host" "$port" 6; then
        echo "$type $host $port"
        exit 0
      else
        # remember first open if none verified
        if [ -z "$first_open" ]; then
          first_open="$type $host $port"
        fi
      fi
    else
      # no curl: accept first open
      echo "$type $host $port"
      exit 0
    fi
  fi
done

if [ -n "$first_open" ]; then
  echo "$first_open"
  exit 0
fi

# if nothing found, exit non-zero
exit 1
