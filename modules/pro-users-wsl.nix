# Название: modules/pro-users-wsl.nix — WSL-specific user helpers
# Кратко: небольшие адаптации для среды WSL: прокси для systemd/автологина и путей
# Last reviewed: 2026-05-03
{ config, pkgs, lib, ... }:

{
  # Этот файл содержит минимальные хелперы для корректной работы пользователей
  # в WSL окружении; он не навязывает глобальных правил и предназначен для
  # импортирования опционально в host config.
  environment.systemPackages = lib.mkDefault (with pkgs; [ ]);
}
