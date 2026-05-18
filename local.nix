# Файл: автосгенерированная шапка — комментарии рефакторятся
{ config, pkgs, ... }:

{
  # Per-host overrides for this machine (cf19). Enable Samba for local LAN use.
  services.samba.enable = true;
  services.samba.openFirewall = true;

  # Let Samba bind to available interfaces so it works on any Wi‑Fi network
  # without hardcoding a CIDR at evaluation time. This makes Samba come up
  # automatically when an interface is present. We keep openFirewall so the
  # previously-declared firewall ports (139/445) are opened on this host.
  services.samba.settings.global = {
    # Do not restrict binding to the static list of interfaces (avoids nmbd
    # waiting for an interface that doesn't exist at boot/eval time).
    "bind interfaces only" = "No";
  };

  # If you prefer a different set of valid users, change below.
  # (This repo's pro-storage module previously defined shares; keep them or
  # override per-host as needed.)
}
