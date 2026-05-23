# Название: modules/pro-heavy-desktop.nix — Тяжёлый desktop-слой для рабочих станций
#
# Цель:
#   Вынести самые тяжёлые прикладные GUI-компоненты из компактного EXWM-слоя,
#   чтобы базовая workstation-станция оставалась легче и прозрачнее.
#
# Контракт:
#   - Модуль добавляет только тяжёлые прикладные GUI-пакеты.
#   - Не настраивает Xserver, display manager или окно входа.
#   - Подключается только на хостах, которым нужен полный рабочий desktop-слой.
#
# Что здесь живёт:
#   коммуникации, браузер, видео/мультимедиа, тяжёлые десктопные утилиты.
#
# Proof:
#   `nix eval --json .#nixosConfigurations.<host>.config.environment.systemPackages`
#   и проверка наличия/отсутствия тяжёлых GUI-пакетов.
{ pkgs, lib, ... }:

{
  environment.systemPackages = lib.mkDefault (with pkgs; [
    chromium
    telegram-desktop
    element-desktop
    jami
    weechat
    ffmpegthumbnailer
    baobab
  ]);
}
