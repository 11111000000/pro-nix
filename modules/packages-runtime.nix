{ config, pkgs, lib, ... }:

# Minimal runtime packages that must be present in the final system profile.
# Keep this list intentionally small: these packages are required for system
# activation, shell access, and basic maintenance.

with pkgs;

# Export as a NixOS module so it can be reliably included via `imports` and
# also imported directly to read the list (as configuration.nix does).
{
  # Модуль экспортирует базовый набор рантайм‑пакетов. Он использует
  # lib.mkDefault в местах, где другие модули могут дополнять список.
  environment.systemPackages = lib.mkDefault (with pkgs; [
    bashInteractive
    openssh
    coreutils
    procps
    dbus
  ]);
}
