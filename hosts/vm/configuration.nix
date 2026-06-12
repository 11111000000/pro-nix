{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/pro-users.nix
    ../../modules/pro-docker.nix
    ../../modules/pro-nfs.nix
    ../../modules/pro-spellcheck.nix
  ];

  networking.hostName = "vm";

  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  services.xserver.enable = lib.mkForce false;
  services.displayManager.enable = lib.mkForce false;
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  users.users.root.password = "";

  # VM follows the same shared package policy, including Tor Browser.

  # NFS-клиент: монтируем desktop:/srv/nfs автоматически по обращение.
  pro.nfs.client.enable = true;

  # VM собирается через `mkVmHost` в flake.nix, который НЕ импортирует
  # общий `configuration.nix` (а значит и `headscale.nix`). Здесь нельзя
  # ссылаться на `headscale.*` — опция не существует в этом evaluation.
}
