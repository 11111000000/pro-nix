# Название: modules/pro-desktop.nix — Настройки рабочего стека и шрифтов
# Summary (EN): Desktop environment defaults, display manager, fonts and audio
# Цель:
#   Сформировать устойчивый и предсказуемый графический профиль: включить
#   дисплейный менеджер, дефолты сессии, набор шрифтов и современный аудиостек.
# Контракт:
#   Опции: services.xserver.enable, services.displayManager.gdm.enable,
#           fonts.packages — список шрифтов; environment.etc.* — конфигурация GTK/Qt.
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
  # Compatibility façade: the public module name stays stable while the real
  # responsibilities are split into focused session modules. This preserves the
  # huawei behavior while making the composition readable for cf19 and future
  # hosts.
  imports = [
    ./session/base.nix
    ./session/exwm.nix
    ./session/fonts.nix
    ./session/audio.nix
    ./session/cinnamon.nix
  ];

  # Firefox remains here for now as a compatibility app-policy bridge. It is
  # not part of the session mechanics; it will move into a dedicated app layer
  # once that slice is introduced.
  programs.firefox.enable = true;
  programs.firefox.package = pkgs.firefox;
}
