# Название: modules/pro-docker.nix — Docker-демон и базовый CLI-инструментарий
# Кратко: включает Docker на хосте и кладёт CLI-утилиты в user PATH для
# всех членов группы `docker` (см. modules/pro-users.nix).
#
# Цель:
#   Сделать docker одинаково рабочим на всех 4 хостах (cf19, huawei,
#   desktop, vm): демон стартует автоматически, CLI-команды `docker`,
#   `docker-compose`, `docker-credential-helpers` доступны всем юзерам,
#   состоящим в группе `docker` (а их всех добавляет pro-users.nix).
#
# Контракт:
#   Опции: virtualisation.docker.enable, docker.rootless (off по умолчанию).
#   Побочные эффекты: запускает docker.socket/dockerd; открывает бридж
#   `docker0` в firewall (pro-services.nix уже доверяет этому интерфейсу).
#
# Как проверить (Proof):
#   `systemctl status docker` и `docker ps` от имени пользователя из
#   группы `docker` без sudo.
#
# Last reviewed: 2026-06-13
{ pkgs, lib, ... }:

{
  # Демон в обычном (root) режиме — проще и совместимо с rootless
  # mount/socket-схемами не для всех наших хостов (cf19 не имеет
  # cgroups v2, huawei на классической rootfs). Юзеры из группы
  # `docker` работают с демоном через /var/run/docker.sock.
  virtualisation.docker.enable = true;

  # Системный уровень: docker CLI / compose / credential-helpers в PATH
  # для всех юзеров. user-уровень дублируется в modules/pro-users-nixos.nix,
  # чтобы не зависеть от того, перебил ли хост systemPackages.
  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    docker-credential-helpers
  ];
}
