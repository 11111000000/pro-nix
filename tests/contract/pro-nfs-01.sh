#!/usr/bin/env bash
set -euo pipefail

# Контрактный тест: NFS-шара desktop:/srv/nfs → /mnt/desktop на клиентах.
#
# Проверяет, что:
#   1. pro.nfs.server включается на desktop, pro.nfs.client на cf19/huawei.
#   2. mnt-desktop.mount декларируется с top-level `wantedBy` (→ [Install]),
#      а НЕ `unitConfig.WantedBy` (→ [Unit], где systemd его игнорирует).
#      Регрессия 2026-06-15: `WantedBy` в [Unit] → unit не стартует при
#      загрузке, `mount | grep desktop` пусто при живом сервере.
#   3. mountConfig.Options — одна comma-separated строка, а не список.
#      Регрессия 2026-06-15: список из 9 элементов NixOS рендерит как
#      9 отдельных `Options=` строк, каждая следующая затирает предыдущую;
#      до фикса оставалось только `noatime`.
#   4. fstab-генератор НЕ используется (x-systemd.automount отсутствует
#      — он ломает nixos-rebuild switch на reload automount-юнитов).
#   5. На сервере /srv/nfs создаётся через tmpfiles (setgid 2775 root:pro).
#   6. sec=sys (UID-маппинг 1:1, доверенная LAN) + no_root_squash (чтобы
#      root на клиенте == root на сервере).
#
# Proof-чек: см. §6 AGENTS.md.

root="$(cd "$(dirname "$0")/../.." && pwd)"

f_nfs="$root/modules/pro-nfs.nix"
f_storage="$root/modules/pro-storage.nix"
f_desktop="$root/hosts/desktop/configuration.nix"
f_cf19="$root/hosts/cf19/configuration.nix"
f_huawei="$root/hosts/huawei/configuration.nix"

for f in "$f_nfs" "$f_storage" "$f_desktop" "$f_cf19" "$f_huawei"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: missing file $f" >&2
    exit 2
  fi
done

ok=0

# 1. opt-in на нужных хостах
echo -n "01 pro.nfs opt-in: desktop=server, cf19/huawei=client… "
if rg -q 'pro\.nfs\.server\.enable\s*=\s*true' "$f_desktop" \
   && rg -q 'pro\.nfs\.client\.enable\s*=\s*true' "$f_cf19" \
   && rg -q 'pro\.nfs\.client\.enable\s*=\s*true' "$f_huawei"; then
  ok=$((ok+1))
  echo "ok"
else
  echo "missing pro.nfs opt-in on a host (server: desktop, client: cf19, huawei)" >&2
  exit 3
fi

# 2. НЕ должно быть `unitConfig = { WantedBy = ... }` (регрессия 2026-06-15).
#    Должно быть top-level `wantedBy = [ "multi-user.target" ];`.
echo -n "02 mnt-desktop.mount: WantedBy в [Install], не в [Unit]… "
if rg -q 'unitConfig\s*=\s*\{[^}]*WantedBy' "$f_nfs"; then
  echo "FAIL: \`unitConfig.WantedBy\` ставит WantedBy в [Unit] — systemd игнорирует." >&2
  echo "      Используй top-level \`wantedBy = [ ... ]\` (→ [Install])." >&2
  exit 4
fi
if ! rg -qU 'systemd\.mounts\b[\s\S]*?\{\s*name\s*=\s*"mnt-desktop\.mount"[\s\S]*?wantedBy\s*=\s*\[[\s\S]*?\]' "$f_nfs"; then
  echo "FAIL: top-level \`wantedBy\` отсутствует в systemd.mounts entry для mnt-desktop.mount" >&2
  exit 4
fi
ok=$((ok+1))
echo "ok"

# 3. mountConfig.Options — одна comma-separated строка, не список.
echo -n "03 mnt-desktop.mount: Options — одна comma-separated строка… "
# В pro-nfs.nix ровно один systemd.mounts entry (mnt-desktop.mount), поэтому
# проверяем Options на уровне файла. Ловим регрессию: список
# `Options = [ "vers=4.2" ... ]` рендерится NixOS как 9 отдельных `Options=`
# строк, systemd берёт последнюю (noatime).
if rg -qU 'Options\s*=\s*\[[\s\S]*?"vers=' "$f_nfs"; then
  echo "FAIL: \`mountConfig.Options = [ ... ]\` рендерится как 9 отдельных \`Options=\` строк," >&2
  echo "      systemd берёт последнюю. Замени на одну строку: \`Options = \"a,b,c\"\`." >&2
  exit 5
fi
if ! rg -qU 'mountConfig\s*=\s*\{[\s\S]*?Options\s*=\s*"' "$f_nfs"; then
  echo "FAIL: не нашёл \`mountConfig.Options = \"...\"\` (одна строка)" >&2
  exit 5
fi
ok=$((ok+1))
echo "ok"

# 4. x-systemd.automount НЕ задан как активная опция (ломает `nixos-rebuild switch`
#    через CanReload=no на automount-юнитах). Упоминание в комментарии ОК.
#    Проверяем именно в активной строке `mountConfig.Options = "..."`,
#    где fstab-стиль опция реально появляется.
echo -n "04 mnt-desktop.mount: без активного x-systemd.automount… "
if rg -qU 'Options\s*=\s*"[^"]*x-systemd\.automount' "$f_nfs"; then
  echo "FAIL: x-systemd.automount активен в mount options — \`nixos-rebuild switch\` падает с кодом 4" >&2
  echo "      при reload automount-юнита. Используй plain mount-юнит (см. комментарий в pro-nfs.nix)." >&2
  exit 6
fi
ok=$((ok+1))
echo "ok"

# 5. tmpfiles: /srv/nfs создаётся на сервере с setgid 2775 root:pro.
#    NB: правило живёт в pro-storage.nix (общая tmpfiles-секция для SMB/Syncthing/NFS).
echo -n "05 server: /srv/nfs tmpfiles rule (2775 root:pro)… "
if rg -q '"?d /srv/nfs 2775 root pro' "$f_storage"; then
  ok=$((ok+1))
  echo "ok"
else
  echo "FAIL: нет tmpfiles-правила \`d /srv/nfs 2775 root pro\` в pro-storage.nix" >&2
  exit 7
fi

# 6. exports: sec=sys + no_root_squash (UID 1:1 в доверенной LAN).
echo -n "06 server: exports sec=sys + no_root_squash… "
if rg -q 'sec=sys' "$f_nfs" && rg -q 'no_root_squash' "$f_nfs"; then
  ok=$((ok+1))
  echo "ok"
else
  echo "FAIL: exports должны содержать \`sec=sys\` (UID 1:1) и \`no_root_squash\` (root на клиенте = root на сервере)" >&2
  exit 8
fi

# 7. mount options: nofail + _netdev (не блокировать загрузку при отсутствии сети/сервера).
echo -n "07 client: mount nofail + _netdev (resilient boot)… "
if rg -q 'nofail' "$f_nfs" && rg -q '_netdev' "$f_nfs"; then
  ok=$((ok+1))
  echo "ok"
else
  echo "FAIL: mount options должны содержать \`nofail\` и \`_netdev\`" >&2
  exit 9
fi

# 8. Тачки за firewall: NFSv4 хочет 2049/tcp+udp.
echo -n "08 server: firewall 2049/tcp+udp открыт… "
if rg -q 'allowedTCPPorts\s*=\s*\[[\s\S]*?2049' "$f_nfs" \
   && rg -q 'allowedUDPPorts\s*=\s*\[[\s\S]*?2049' "$f_nfs"; then
  ok=$((ok+1))
  echo "ok"
else
  echo "FAIL: firewall должен открывать 2049/tcp и 2049/udp для NFSv4" >&2
  exit 10
fi

echo
echo "pro-nfs contract: $ok/8 checks passed"
exit 0
