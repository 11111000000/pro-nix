# Название: modules/packages-runtime.nix — Базовый системный runtime
# Кратко: минимальный набор пакетов, который нужен, чтобы система жила и
# можно было войти в shell, поднять сеть и выполнить первичное обслуживание.
#
# Файловый контракт:
#   Цель: обеспечить системный набор утилит для старта, shell-доступа и
#     базового обслуживания системы.
#   Контракт: environment.systemPackages здесь остаётся маленьким и не
#     финализирует workstation-слой; более тяжёлые пакеты должны приходить из
#     host composition или отдельного рабочего слоя.
#   Proof: tests/contract/test_runtime_packages.sh
#
# Цель:
#   Определить минимальный набор пакетов, необходимых для активации, shell-доступа
#   и базового обслуживания системы. Остальные пакеты добавляются через environment.systemPackages или отдельные модули.
#
# Контракт:
#   Опции: environment.systemPackages (базовый список, может быть дополнен).
#   Побочные эффекты: добавляет только минимальный runtime: shell, базовые
#   утилиты, диагностику и операторские CLI.
#
# Предпосылки:
#   Используется в NixOS-конфигурации; пакеты должны присутствовать в pkgs.
#
# Как проверить (Proof):
#   `nix eval .#nixosConfigurations.<host>.config.environment.systemPackages --json`
#   и проверка наличия runtime-утилит в выводе.
#
# Last reviewed: 2026-05-03
{ pkgs, ... }:

{
  # Мы намеренно держим этот слой узким: это не рабочая станция и не desktop,
  # а только та опорная точка, без которой система не оживает.
  # `pkgs.emacs` here is the nixpkgs default; the emacs30 preference
  # applied by flake.nix still flows to emacs/ and modules/session-exwm*
  # via `emacsPkg` specialArgs, where it actually matters (Emacs session
  # wrapper, X session). For the system-wide emacs binary this generic
  # entry is enough and keeps the module free of specialArgs.
  environment.systemPackages = with pkgs; [
    bashInteractive
    openssh
    python3
    coreutils
    procps
    dbus
    gawk
    kbd
    mc
    emacs
    rxvt-unicode
    curl
    wget
    jq
    just
    git
    gh
    ripgrep
    fd
    findutils
    tmux
    tree
    htop
    lsof
    file
    ncdu
    time

    # ALSA utilities и beep добавлены в базовый runtime чтобы обеспечить
    # наличие amixer/alsamixer/speaker-test/aplay и утилиты beep на всех хостах.
    alsa-utils
    beep
  ];
}
