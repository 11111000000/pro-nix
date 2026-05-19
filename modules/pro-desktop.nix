# Название: modules/pro-desktop.nix — Настройки рабочего стека и прикладной GUI-слой
# Summary (EN): Desktop environment defaults, display manager, fonts, audio and workstation GUI packages.
# Цель:
#   Сформировать устойчивый и предсказуемый графический профиль: включить
#   дисплейный менеджер, дефолты сессии, набор шрифтов, аудиостек и базовые
#   пользовательские GUI-приложения.
# Контракт:
#   Опции: services.xserver.enable, services.displayManager.gdm.enable,
#           fonts.packages — список шрифтов; environment.systemPackages — GUI-пакеты.
#   Побочные эффекты: добавляет xsession файл для EXWM, разворачивает шрифты в
#   профиль, настраивает pipewire/pulseaudio сопутствующие службы.
# Предпосылки:
#   Требуются пакеты terminus_font, noto-fonts; некоторые конфигурации зависят
#   от версии NixOS (опции могут отсутствовать в старых версиях).
# Как проверить (Proof):
#   Откройте GDM/EXWM с этим профилем или проверьте наличие $out/share/xsessions/exwm.desktop
# Last reviewed: 2026-05-03
{ config, pkgs, lib, ... }:

{
  imports = [
    ./session/base.nix
    ./session/exwm.nix
    ./session/fonts.nix
    ./session/audio.nix
    ./session/cinnamon.nix
  ];

  programs.firefox.enable = true;
  programs.firefox.package = pkgs.firefox;

  environment.systemPackages = with pkgs; [
    chromium
    telegram-desktop
    element-desktop
    jami
    weechat
    feh
    xterm
    pcmanfm
    xfce.thunar
    ffmpegthumbnailer
    pavucontrol
    copyq
    scrot
    udiskie
    dunst
    pasystray
    libnotify
    volumeicon
    caffeine-ng
    redshift
    flameshot
    batsignal
    playerctl
    baobab
    duc
    networkmanagerapplet
    blueman
    obexd
    bluez
    vlc
    mpv
    deluge
    evince
    zathura
    lm_sensors
    powertop
    acpi
  ];
}
