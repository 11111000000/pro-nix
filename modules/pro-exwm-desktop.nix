# Название: modules/pro-exwm-desktop.nix — Дополнительный EXWM/desktop-слой для рабочих станций
#
# Цель:
#   Выделить «тяжёлый» прикладной GUI-слой (браузер, мессенджеры, медиа и
#   утилиты рабочего стола), который логически относится к EXWM-рабочей
#   станции, но не обязателен для минимального профиля.
#
# Контракт:
#   - Модуль добавляет вклад в environment.systemPackages, не финализируя
#     список пакетов и не вмешиваясь в системные опции.
#   - Не включает/отключает display manager, Xserver или оконный менеджер —
#     этим занимаются отдельные модули (session-*.nix, profile-exwm-minimal.nix
#     и др.).
#   - Предназначен для использования на рабочих станциях (cf19, huawei и др.)
#     поверх базового runtime и EXWM-профиля.
#
# Как проверять (Proof):
#   - `nix eval --json .#nixosConfigurations.<host>.config.environment.systemPackages`
#     и проверка наличия/отсутствия нужных GUI-пакетов.
{ pkgs, lib, ... }:

{
  environment.systemPackages = lib.mkDefault (with pkgs; [
    feh
    xterm
    scrot
    pasystray
    libnotify
    volumeicon
    caffeine-ng
    redshift
    batsignal
    playerctl
    networkmanagerapplet
    blueman
    obexd
    bluez
    evince
    zathura
    lm_sensors
    powertop
    acpi
    pavucontrol
    copyq
    udiskie
    dunst
    flameshot
    duc
    mpv
  ]);
}
