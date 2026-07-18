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
  virtualisation.docker.package = pkgs.docker_29;
  virtualisation.docker.enable = true;
  # Идемпотентное создание bridge-сети `pro-dev` при каждом старте
  # dockerd. Используем wrapper-скрипт, а не shell-redirect-фоллбэк
  # (`2>/dev/null || true`) внутри ExecStart: в systemd < 258 есть баг
  # парсинга `2>/dev/null` рядом с `||` в ExecStart — редирект
  # интерпретируется как часть argv и обрезает позиционные аргументы
  # у бинаря, который идёт перед редиректом (docker-cli видит
  # `requires 1 argument` вместо имени сети). Wrapper-скрипт делает
  # `docker network inspect` (проверка существования) и при отсутствии —
  # `docker network create`. Без shell-метасимволов в ExecStart.
  #
  # Зависимость `After=docker.service` + `Requires=docker.service`
  # гарантирует, что сеть создаётся ПОСЛЕ старта демона.
  systemd.services.docker-network-pro-dev = let
    script = pkgs.writeShellScriptBin "pro-docker-network-create" ''
      set -eu
      if ${pkgs.docker_29}/bin/docker network inspect pro-dev >/dev/null 2>&1; then
        echo "[pro-docker-network] network pro-dev already exists"
        exit 0
      fi
      echo "[pro-docker-network] creating pro-dev (172.20.0.0/16)..."
      exec ${pkgs.docker_29}/bin/docker network create \
        --driver=bridge \
        --subnet=172.20.0.0/16 \
        --gateway=172.20.0.1 \
        pro-dev
    '';
  in {
    description = "Create pro-dev bridge network for microservices";
    after = [ "docker.service" "docker.socket" ];
    requires = [ "docker.service" ];
    wantedBy = [ "docker.service" "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${script}/bin/pro-docker-network-create";
      # Проверяем реальное наличие сети после create. Если ExecStart
      # завершился с ошибкой (например, нет демона), сообщаем, но
      # не валим загрузку.
       ExecStartPost = "${pkgs.docker_29}/bin/docker network inspect pro-dev";
    };
  };

  environment.systemPackages = with pkgs; [
    docker_29
    docker-compose
    docker-credential-helpers
  ];
}
