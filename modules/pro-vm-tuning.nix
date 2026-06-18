# Название: modules/pro-vm-tuning.nix — Глобальный VM-тюнинг (sysctl vm.*) для десктопов pro-nix
# Summary (EN): Lower swappiness, gentler writeback ratios, and softer vfs_cache_pressure
#   for desktop workloads (avoids SSD thrashing from default server-tuned kernel vm.*).
#
# Цель:
#   Дефолтные значения ядра Linux оптимизированы под серверы (агрессивный
#   swap, большие writeback bursts). На десктопе с SSD это даёт лишний
#   износ диска и UI-latency при случайных записях. Модуль выставляет
#   значения, дружелюбные к десктопным нагрузкам.
#
# Контракт:
#   Опции:
#     pro.vmTuning.enable — bool (default false), глобальный sysctl-тюнинг.
#   Побочные эффекты: пишет в /etc/sysctl.d/ значения vm.* (через
#     boot.kernel.sysctl).
#   Хост может отключить: pro.vmTuning.enable = lib.mkForce false;
#
# Предпосылки:
#   Назначение sysctl — прозрачно для всех сервисов. zram-раздел (если
#   включён через services.zramSlice) не затрагивается.
#
# Как проверить (Proof):
#   `sysctl vm.swappiness vm.dirty_ratio vm.dirty_background_ratio vm.vfs_cache_pressure`
#   — должны вернуть 10, 15, 5, 50 соответственно.
#
# Last reviewed: 2026-06-16
{ config, lib, pkgs, ... }:

let
  cfg = config.pro.vmTuning;
in
{
  options.pro.vmTuning = {
    enable = lib.mkEnableOption
      "Tune kernel VM parameters for desktop workloads (lower swappiness, smoother writeback, gentler vfs cache pressure).";
  };

  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.dirty_background_ratio" = 5;
      "vm.dirty_ratio" = 15;
      "vm.vfs_cache_pressure" = 50;
    };
  };
}
