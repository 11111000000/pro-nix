#!/usr/bin/env bash
set -euo pipefail

# Контрактный тест: сетевой стек pro-nix.
#
# Проверяет, что новые модули pro-hosts / pro-network / pro-ssh-clients
# корректно описаны в репо:
#   1. Реестр pro.hosts содержит все ожидаемые имена (single source of truth).
#   2. pro-network правит avahi + nssmdns + resolved MulticastDNS.
#   3. pro-ssh-clients генерирует /etc/ssh/ssh_config.d/pro.conf с Host-блоками.
#   4. ssh_config.d провайдится через environment.etc (а не через костыли
#      типа sed-in-activation).
#
# Proof-чек: см. §6 AGENTS.md.

root="$(cd "$(dirname "$0")/../.." && pwd)"

f_hosts="$root/modules/pro-hosts.nix"
f_net="$root/modules/pro-network.nix"
f_ssh="$root/modules/pro-ssh-clients.nix"
f_head="$root/modules/headscale.nix"

for f in "$f_hosts" "$f_net" "$f_ssh" "$f_head"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: missing module $f" >&2
    exit 2
  fi
done

ok=0

# 1. Реестр хостов
echo -n "01 pro.hosts registry… "
if rg -q '^[[:space:]]*desktop[[:space:]]*=[[:space:]]*\{' "$f_hosts" \
   && rg -q '^[[:space:]]*cf19[[:space:]]*=[[:space:]]*\{' "$f_hosts" \
   && rg -q '^[[:space:]]*huawei[[:space:]]*=[[:space:]]*\{' "$f_hosts" \
   && rg -q '^[[:space:]]*vm[[:space:]]*=[[:space:]]*\{' "$f_hosts"; then
  ok=$((ok+1))
  echo "ok"
else
  echo "MISSING expected host entries (desktop/cf19/huawei/vm)" >&2
  exit 3
fi

# 2. pro-network: avahi + nssmdns
# NB: регекспы делаем line-oriented, т.к. `services.avahi` и `nssmdns4 = true;`
# могут быть на разных строках (так структурно удобнее в Nix).
echo -n "02 pro-network: mDNS + NSS… "
if rg -qU 'services\.avahi\s*=\s*\{[\s\S]*nssmdns4\s*=\s*true' "$f_net" \
   && rg -qU 'services\.avahi\s*=\s*\{[\s\S]*nssmdns6\s*=\s*true' "$f_net" \
   && rg -q '\bnssmdns\b' "$f_net" \
   && rg -q 'MulticastDNS=yes' "$f_net"; then
  ok=$((ok+1))
  echo "ok"
else
  echo "MISSING mDNS/NSS configuration" >&2
  exit 3
fi

# 3. pro-ssh-clients: рендерится через environment.etc
echo -n "03 pro-ssh-clients: ssh_config.d generation… "
if rg -q 'environment\.etc\."ssh/ssh_config\.d/pro\.conf"' "$f_ssh" \
   && rg -q 'Host \*' "$f_ssh" \
   && rg -q 'IdentityFile' "$f_ssh" \
   && rg -q 'HashKnownHosts yes' "$f_ssh"; then
  ok=$((ok+1))
  echo "ok"
else
  echo "MISSING ssh_config.d generation" >&2
  exit 3
fi

# 4. headscale: рабочий base_domain, dns, derp
echo -n "04 headscale: base_domain + DNS… "
if rg -q 'base_domain' "$f_head" \
   && rg -q 'magic_dns' "$f_head" \
   && rg -q 'prefix_v4' "$f_head" \
   && rg -q 'derp' "$f_head"; then
  ok=$((ok+1))
  echo "ok"
else
  echo "MISSING headscale DNS/DERP configuration" >&2
  exit 3
fi

# 5. Только desktop включает headscale.enable; cf19/huawei выключают
# его явно. vm намеренно не трогает опцию (собирается через mkVmHost,
# который не импортирует общий configuration.nix).
echo -n "05 headscale control plane: only desktop enabled… "
desktop_has=$(rg -c 'headscale\.enable[[:space:]]*=[[:space:]]*lib\.mkForce[[:space:]]+true' "$root/hosts/desktop/configuration.nix" || true)
other_off=0
for h in cf19 huawei; do
  if rg -q 'headscale\.enable[[:space:]]*=[[:space:]]*lib\.mkForce[[:space:]]+false' "$root/hosts/$h/configuration.nix"; then
    other_off=$((other_off+1))
  fi
done
if [ "${desktop_has:-0}" -ge 1 ] && [ "$other_off" -ge 2 ]; then
  ok=$((ok+1))
  echo "ok"
else
  echo "desktop_enable=$desktop_has other_off=$other_off" >&2
  exit 3
fi

echo
echo "pro-network contract: $ok/5 checks passed"
exit 0
