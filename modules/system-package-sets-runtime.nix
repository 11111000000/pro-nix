{ pkgs, ... }:

with pkgs;

{
  # Minimal runtime packages required by all hosts
  runtimePackages = [
    bashInteractive
    openssh
    python3
    coreutils
    file
    procps
    dbus
    gawk
    kbd
    mc
    emacsPkg
    nix
    nix-info
    acpi
    lm_sensors
    stress-ng
    fio
    powertop
    neofetch
    openssl
    unzip
    smartmontools
    parted
    usbutils
    pciutils
    efibootmgr
    dosfstools
    exfatprogs
    ntfs3g
    iftop
    iotop
    iperf3
    dnsutils
    atop
    cifs-utils
    avahi
    obsidian  # Markdown knowledge base; available on every host via PATH
    nodePackages.mermaid-cli
    # opencode removed from the runtime set: it is delivered via the
    # Home Manager wrapper path, not system runtime.
  ];
}
