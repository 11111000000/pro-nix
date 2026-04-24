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

  config = lib.mkIf config.services.zramSlice.enable {
    environment.etc."systemd/enable-zram.service".text = lib.mkString (''
[Unit]
Description=Enable zram swap
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'set -e; \n+  # compute size in bytes: if cfg.size == auto -> 50% of MemTotal capped to 16G; else use provided MB value\n+  if [ "${cfg.size}" = "auto" ]; then\n+    mem_kb=$(awk "/MemTotal/ {print \$2}" /proc/meminfo);\n+    size_mb=$(( mem_kb/1024/2 ));\n+    if [ $size_mb -gt 16384 ]; then size_mb=16384; fi;\n+  else\n+    size_mb=${cfg.size};\n+  fi;\n+  echo "Configuring zram with ${size_mb}M";\n+  modprobe zram max_comp_streams=4 || true;\n+  echo $((size_mb * 1024 * 1024)) > /sys/block/zram0/disksize;\n+  mkswap /dev/zram0 || true;\n+  swapon -p 5 /dev/zram0 || true;\n+  exit 0'
'' );

    systemd.services."enable-zram" = {
      description = "Enable zram swap at boot";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = "/bin/sh -c 'systemd-cat -t enable-zram sh -c \"(sleep 1; /bin/true)\"'";
      };
      # We will not use serviceConfig ExecStart; instead use the file created above as a unit drop-in
      # Activate the drop-in by enabling the unit
      enable = true;
    };
  };

  # opencode.slice unit
  config = lib.mkIf config.services.opencodeSlice.enable {
    environment.etc."systemd/opencode.slice".text = lib.mkString (''
[Slice]
Description=Slice for opencode and heavy agent processes
MemoryMax=${config.services.opencodeSlice.memoryMax}
CPUQuota=${config.services.opencodeSlice.cpuQuota}
IOWeight=${toString config.services.opencodeSlice.ioWeight}
'' );
  };

  # Ensure systemd reload after activation so units are recognized
  systemd.postReload = lib.mkIf (config.services.zramSlice.enable || config.services.opencodeSlice.enable) true;

}
