{ config, lib, pkgs, ... }:

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
/run/current-system/sw/sbin/modprobe zram max_comp_streams=4 || true
echo $((size_mb * 1024 * 1024)) > /sys/block/zram0/disksize
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
