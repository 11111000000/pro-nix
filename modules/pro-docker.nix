# Название: modules/pro-docker.nix — Docker-демон и базовый CLI-инструментарий
# Кратко: включает Docker на хосте и кладёт CLI-утилиты в user PATH для
# всех членов группы `docker` (см. modules/pro-users.nix). Также создаёт
# дефолтную bridge-сеть `pro-dev` для микросервисной разработки.
#
# Цель:
#   Сделать docker одинаково рабочим на всех 4 хостах (cf19, huawei,
#   desktop, vm): демон стартует автоматически, CLI-команды `docker`,
#   `docker-compose`, `docker-credential-helpers` доступны всем юзерам,
#   состоящим в группе `docker` (а их всех добавляет pro-users.nix).
#
#   Дополнительно: именованная bridge-сеть `pro-dev` для удобной связки
#   сервисов по имени (compose-стек подключается через
#   `networks: [ { name: pro-dev } ]`). Сеть создаётся systemd-юнитом
#   при старте dockerd (NixOS 25.11 не имеет
#   `virtualisation.docker.networks`, поэтому используем однократный
#   ExecStart=post с `docker network create`).
#
# Контракт:
#   Опции: virtualisation.docker.enable, systemd.services.docker-network-pro-dev.
#   Побочные эффекты: запускает docker.socket/dockerd; создаёт bridge
#   `pro-dev` (172.20.0.0/16); открывает бридж `docker0` в firewall
#   (pro-services.nix уже доверяет этому интерфейсу).
#
# Как проверить (Proof):
#   `systemctl status docker` и `docker ps` от имени пользователя из
#   группы `docker` без sudo. `docker network inspect pro-dev` покажет
#   сеть с подсетью 172.20.0.0/16.
#
# Last reviewed: 2026-06-13
{ pkgs, lib, ... }:

{
  # Демон в обычном (root) режиме — проще и совместимо с rootless
  # mount/socket-схемами не для всех наших хостов (cf19 не имеет
  # cgroups v2, huawei на классической rootfs). Юзеры из группы
  # `docker` работают с демоном через /var/run/docker.sock.
  virtualisation.docker.enable = true;

  # Идемпотентное создание bridge-сети `pro-dev` при каждом старте
  # dockerd. `docker network create` возвращает non-zero, если сеть
  # уже есть — это OK, нас интересует только «сеть существует после
  # запуска юнита». Используем `|| true` для идемпотентности.
  #
  # Зависимость `After=docker.service` + `Requires=docker.service`
  # гарантирует, что сеть создаётся ПОСЛЕ старта демона.
  systemd.services.docker-network-pro-dev = {
    description = "Create pro-dev bridge network for microservices";
    after = [ "docker.service" "docker.socket" ];
    requires = [ "docker.service" ];
    wantedBy = [ "docker.service" "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.docker}/bin/docker network create --driver=bridge --subnet=172.20.0.0/16 --gateway=172.20.0.1 pro-dev 2>/dev/null || true";
      # Проверяем реальное наличие сети после `create || true` —
      # если ExecStart завершился с ошибкой (например, нет демона),
      # сообщаем, но не валим загрузку.
      ExecStartPost = "${pkgs.docker}/bin/docker network inspect pro-dev";
    };
  };

  # Системный уровень: docker CLI / compose / credential-helpers в PATH
  # для всех юзеров. user-уровень дублируется в modules/pro-users-nixos.nix,
  # чтобы не зависеть от того, перебил ли хост systemPackages.
  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    docker-credential-helpers
  ];
}
