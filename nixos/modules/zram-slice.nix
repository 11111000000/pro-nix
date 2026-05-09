{ config, lib, pkgs, ... }:

# Назначение: обеспечить runtime-настройку zram swap и опциональный opencode.slice.
# Инварианты:
# - Скрипты и unit-файлы должны быть идемпотентными и безопасными для повторного запуска.
# - Модуль не вносит неожиданных изменений в systemPackages.

let
  cfg = config.services.zramSlice;
in
{
  options.services.zramSlice = {
    enable = lib.mkEnableOption "Enable runtime zram swap setup via systemd";
    size = lib.mkOption {
      type = lib.types.str;
      description = "Size for zram in MB or the string 'auto' (default: auto = 50% RAM capped to 16384MB).";
      default = "auto";
    };
  };

  options.services.opencodeSlice = {
    enable = lib.mkEnableOption "Install opencode.slice unit to limit agent resources";
    memoryMax = lib.mkOption { type = lib.types.str; default = "4G"; description = "MemoryMax for opencode.slice"; };
    cpuQuota = lib.mkOption { type = lib.types.str; default = "80%"; description = "CPUQuota for opencode.slice"; };
    ioWeight = lib.mkOption { type = lib.types.int; default = 200; description = "IOWeight for opencode.slice"; };
  };

  config = lib.mkMerge [
    (lib.mkIf config.services.zramSlice.enable {
      # Create a small script in /etc that performs the zram setup with chosen size
      # use a plain string here; lib.mkString isn't available in all nixpkgs
      environment.etc."enable-zram.sh" = {
        text = ''
#!/bin/sh
set -e
# compute size in MB
if [ "${cfg.size}" = "auto" ]; then
  # use absolute path for awk to avoid minimal PATH in systemd ExecStart
  mem_kb=$(/run/current-system/sw/bin/awk '/MemTotal/ {print $2}' /proc/meminfo)
  size_mb=$(( mem_kb/1024/2 ))
  if [ $size_mb -gt 16384 ]; then size_mb=16384; fi
else
  size_mb=${cfg.size}
fi
echo "Configuring zram with $size_mb M"
# use absolute paths for commands invoked from unit
# Be defensive: if zram is already configured or swap is active on /dev/zram0,
# do not fail the script. Attempt a gentle reset if writing disksize fails.
/run/current-system/sw/sbin/modprobe zram max_comp_streams=4 || true

# If disksize already non-zero, assume configured and exit cleanly.
if [ -e /sys/block/zram0/disksize ]; then
  current=$(cat /sys/block/zram0/disksize 2>/dev/null || echo 0)
  if [ "$current" -ne 0 ]; then
    echo "zram: /sys/block/zram0/disksize already set ($current). Skipping configuration."
    exit 0
  fi
fi

# If swap is active on /dev/zram0, skip configuration.
if /run/current-system/sw/bin/swapon --noheadings --show=NAME 2>/dev/null | /run/current-system/sw/bin/grep -q '/dev/zram0'; then
  echo "zram: swap on /dev/zram0 already active; skipping."
  exit 0
fi

# Try to set disksize; if it fails, attempt a reset and retry once.
if ! (echo $((size_mb * 1024 * 1024)) > /sys/block/zram0/disksize) 2>/dev/null; then
  echo "zram: failed to write disksize; attempting reset"
  /run/current-system/sw/sbin/swapoff /dev/zram0 2>/dev/null || true
  /run/current-system/sw/sbin/modprobe -r zram 2>/dev/null || true
  /run/current-system/sw/sbin/modprobe zram max_comp_streams=4 || true
  if ! (echo $((size_mb * 1024 * 1024)) > /sys/block/zram0/disksize) 2>/dev/null; then
    echo "zram: cannot set disksize; leaving without enabling zram" >&2
    exit 0
  fi
fi

/run/current-system/sw/sbin/mkswap /dev/zram0 || true
/run/current-system/sw/sbin/swapon -p 5 /dev/zram0 || true
exit 0
'';
        mode = "0755";
      };

      systemd.services."enable-zram" = {
        description = "Enable zram swap at boot";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = "yes";
          ExecStart = "/etc/enable-zram.sh";
        };
        enable = true;
      };
    })

    (lib.mkIf config.services.opencodeSlice.enable {
      environment.etc."systemd/opencode.slice".text = ''
[Slice]
Description=Slice for opencode and heavy agent processes
MemoryMax=${config.services.opencodeSlice.memoryMax}
CPUQuota=${config.services.opencodeSlice.cpuQuota}
IOWeight=${toString config.services.opencodeSlice.ioWeight}
'' ;
    })

    {}
  ];

}
