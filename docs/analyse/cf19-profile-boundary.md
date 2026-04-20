# CF-19 profile boundary

## Keep in `configuration.nix`

- `boot.kernelPackages`
- `hardware.bluetooth.enable`
- `hardware.bluetooth.settings`
- `services.blueman.enable`
- `powerManagement.resumeCommands`
- `services.logind.extraConfig`
- `services.upower`
- `services.power-profiles-daemon.enable`
- `services.xserver.videoDrivers`

## Move to `hosts/cf19/configuration.nix`

- `boot.loader.grub.device`
- `boot.initrd.kernelModules`
- `boot.kernelParams`
- `boot.loader.efi.canTouchEfiVariables`
- `console.font`
- `fileSystems."/"`
- `fileSystems."/boot"`
- `swapDevices`
- `powerManagement.resumeCommands` with `XHCI` and `RP05`
- `powerManagement.powerUpCommands` with `XHCI` and `RP05`

## Still under review

- The shared `powerManagement.resumeCommands` block resets `battery` and `ac` devices after resume.
- Keep it shared only if the same battery/AC recovery is wanted on every laptop profile.
