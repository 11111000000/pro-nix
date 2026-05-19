{ lib, ... }:

{
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

  services.searxng = {
    enable = true;
    listen = "127.0.0.1:8888";
  };

  environment.etc."searxng/settings.yml".text = ''
server:
  secret_key: "changeme-replace-with-secure-random"
  base_url: "http://127.0.0.1:8888"
'';
}
