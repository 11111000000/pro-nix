{ config, lib, pkgs, ... }:

# pro-power-beep.nix — звуковое оповещение при низком заряде батареи
# Контракт:
# - Опция pro.power.lowBattery.beep.enable включает таймер/сервис, который
#   при разряде ниже threshold и статусе Discharging издаёт звуковой сигнал,
#   независимый от микшера (PC speaker), с ALSA‑fallback при отсутствии pcspkr.
# - Не тянет JS/bun/Node; использует только pkgs.beep, pkgs.kmod, pkgs.util-linux,
#   pkgs.alsa-utils.
# Проверка:
# - systemd-analyze verify сгенерированных unit-ов,
# - nix eval наличия опций таймера/сервиса.

let
  cfg = config.pro.power.lowBattery.beep;
  inherit (lib) mkEnableOption mkOption mkIf types mkDefault;

  script = pkgs.writeShellScriptBin "pro-beep-low-battery" (
    ''
    set -euo pipefail

    THRESHOLD="${toString cfg.threshold}"
    COOLDOWN="${toString cfg.cooldownSec}"
    STATE_DIR="/run/pro-beep"
    LAST_FILE="$STATE_DIR/last"

    mkdir -p "$STATE_DIR"

    now=$(date +%s)
    if [ -f "$LAST_FILE" ]; then
      last=$(cat "$LAST_FILE" 2>/dev/null || echo 0)
      if [ "$(( now - last ))" -lt "$COOLDOWN" ]; then
        exit 0
      fi
    fi

    # Найти батарею
    bat=""
    for p in /sys/class/power_supply/BAT*; do
      if [ -d "$p" ]; then bat="$p"; break; fi
    done
    [ -n "$bat" ] || exit 0

    status="$(cat "$bat/status" 2>/dev/null || echo Unknown)"
    cap="$(cat "$bat/capacity" 2>/dev/null || echo 100)"

    case "$status" in
      Discharging)
        : ;;
      *)
        exit 0 ;;
    esac

    cap_num=${"\${cap%%[^0-9]*}"}
    if [ -z "$cap_num" ]; then cap_num=100; fi

    if [ "$cap_num" -ge "$THRESHOLD" ]; then
      exit 0
    fi

    # Порог пройден — пищим
    # 1) PC speaker через beep, если доступен
    ${pkgs.kmod}/bin/modprobe pcspkr 2>/dev/null || true

    did_beep=0
    if [ -x ${pkgs.beep}/bin/beep ]; then
      # Три коротких + пауза + один длиннее
      ${pkgs.beep}/bin/beep -f 1000 -l 150 -r 3 -d 120 -n -f 800 -l 450 || true
      did_beep=1
    else
      # 2) Консольный колокольчик (BEL) — работает на TTY/консоли
      ${pkgs.util-linux}/bin/setterm -blength 400 -bfreq 1000 >/dev/console 2>/dev/null || true
      for i in 1 2 3; do printf "\a" >/dev/console; ${pkgs.coreutils}/bin/sleep 0.2; done
      ${pkgs.coreutils}/bin/sleep 0.3; printf "\a" >/dev/console || true
      did_beep=1
    fi

    # 3) Fallback через ALSA (если нет PC speaker/консоли)
    if [ "$did_beep" -eq 0 ]; then
      if [ -x ${pkgs.alsa-utils}/bin/amixer ] && [ -x ${pkgs.alsa-utils}/bin/speaker-test ]; then
        # Кратковременно поднимем громкость и снимем mute
        ${pkgs.alsa-utils}/bin/amixer -q set Master 80% unmute || true
        # Однотональный сигнал ~0.5 сек
        (${pkgs.alsa-utils}/bin/speaker-test -t sine -f 1000 -l 1 >/dev/null 2>&1 &) || true
        ${pkgs.coreutils}/bin/sleep 0.6
      fi
    fi

    echo "$now" >"$LAST_FILE" 2>/dev/null || true
  '');

in {
  options.pro.power.lowBattery.beep = {
    enable = mkEnableOption "звуковое оповещение при низком заряде батареи" // { default = true; };
    threshold = mkOption {
      type = types.int;
      default = 15;
      description = "Порог процента заряда, ниже которого срабатывает сигнал.";
    };
    cooldownSec = mkOption {
      type = types.int;
      default = 180;
      description = "Минимальный интервал (сек) между сигналами.";
    };
  };

  config = mkIf cfg.enable {
    # PC speaker модуль ядра часто доступен как модуль; пробуем загрузить при срабатывании скрипта.
    # Дополнительно позволяем пользователю потом зафиксировать в host-конфиге boot.blacklistedKernelModules = [ ]; при необходимости.

    systemd.services.pro-beep-low-battery = {
      description = "Beep on low battery (PC speaker/ALSA fallback)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${script}/bin/pro-beep-low-battery";
        # Без PrivateUsers/NoNewPrivileges для надёжности консольных операций
        NoNewPrivileges = true;
      };
    };

    systemd.timers.pro-beep-low-battery = {
      description = "Timer: check battery and beep on threshold";
      wantedBy = [ "timers.target" ];
      partOf = [ "pro-beep-low-battery.service" ];
      # Some NixOS versions expose startLimit* on timers — set safe defaults
      startLimitBurst = 3;
      startLimitIntervalSec = 300;
      unitConfig = { };
      timerConfig = {
        OnBootSec = "120s";
        OnUnitActiveSec = "60s";
        AccuracySec = "10s";
      };
    };
  };
}
