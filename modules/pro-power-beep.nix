{ config, lib, pkgs, ... }:

# pro-power-beep.nix — двухуровневое звуковое оповещение при низком заряде батареи
# Контракт:
# - Опция pro.power.lowBattery.beep.enable включает таймер/сервис, который
#   при разряде ниже warningThreshold (мягкий звук) и/или urgentThreshold
#   (настойчивый звук) и статусе Discharging издаёт звуковой сигнал.
# - Два уровня работают независимо: свои кулдауны, свои last-файлы, разные
#   паттерны. Можно получить warning и urgent в одном цикле опроса.
# - Не тянет JS/bun/Node; использует pkgs.beep, pkgs.kmod, pkgs.util-linux,
#   pkgs.alsa-utils.
#
# Проверка:
# - systemd-analyze verify сгенерированных unit-ов,
# - nix eval наличия опций таймера/сервиса.
#
# Миграция со старого API (threshold / cooldownSec):
#   threshold       → urgentThreshold     (по умолчанию 20)
#   cooldownSec     → urgentCooldownSec   (по умолчанию 120; было 180)
# Новые: warningThreshold (30), warningCooldownSec (300).
#
# Last reviewed: 2026-06-04

let
  cfg = config.pro.power.lowBattery.beep;
  inherit (lib) mkEnableOption mkOption mkIf types mkDefault;

  script = pkgs.writeShellScriptBin "pro-beep-low-battery" (
    ''
    set -euo pipefail

    URGENT="${toString cfg.urgentThreshold}"
    WARNING="${toString cfg.warningThreshold}"
    URGENT_COOLDOWN="${toString cfg.urgentCooldownSec}"
    WARNING_COOLDOWN="${toString cfg.warningCooldownSec}"
    STATE_DIR="/run/pro-beep"
    LAST_URGENT_FILE="$STATE_DIR/last-urgent"
    LAST_WARNING_FILE="$STATE_DIR/last-warning"

    mkdir -p "$STATE_DIR"

    now=$(date +%s)

    # Принудительный тест: опция forceTest или PRO_BEEP_FORCE=1 пищит оба уровня.
    FORCE_DEFAULT="${if cfg.forceTest or false then "1" else "0"}"
    FORCE=${"\${PRO_BEEP_FORCE:-$FORCE_DEFAULT}"}

    urgent_due=0
    warning_due=0

    if [ "$FORCE" != "1" ]; then
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

      # Проверка urgent-уровня
      if [ "$cap_num" -lt "$URGENT" ]; then
        if [ -f "$LAST_URGENT_FILE" ]; then
          last=$(cat "$LAST_URGENT_FILE" 2>/dev/null || echo 0)
          if [ $(( now - last )) -ge "$URGENT_COOLDOWN" ]; then
            urgent_due=1
          fi
        else
          urgent_due=1
        fi
      fi

      # Проверка warning-уровня
      if [ "$cap_num" -lt "$WARNING" ]; then
        if [ -f "$LAST_WARNING_FILE" ]; then
          last=$(cat "$LAST_WARNING_FILE" 2>/dev/null || echo 0)
          if [ $(( now - last )) -ge "$WARNING_COOLDOWN" ]; then
            warning_due=1
          fi
        else
          warning_due=1
        fi
      fi

      if [ "$urgent_due" -eq 0 ] && [ "$warning_due" -eq 0 ]; then
        exit 0
      fi
    else
      urgent_due=1
      warning_due=1
    fi

    # PC speaker / консоль готовы
    ${pkgs.kmod}/bin/modprobe pcspkr 2>/dev/null || true

    # ── Warning: восходящее C-мажорное арпеджио (C5 → E5 → G5) ──
    # ~520 мс, мягкий «дзинь» как дверной звонок.
    play_warning() {
      if [ -x ${pkgs.beep}/bin/beep ]; then
        ${pkgs.beep}/bin/beep \
          -f 523 -l 150 \
          -n -f 659 -l 150 \
          -n -f 784 -l 220 || true
      else
        ${pkgs.util-linux}/bin/setterm -blength 180 -bfreq 800 >/dev/console 2>/dev/null || true
        printf "\a" >/dev/console; ${pkgs.coreutils}/bin/sleep 0.18
        printf "\a" >/dev/console; ${pkgs.coreutils}/bin/sleep 0.18
        printf "\a" >/dev/console
      fi
    }

    # ── Urgent: 3 коротких A5 + финальный C6 ──
    # ~600 мс, настойчиво, но музыкально.
    play_urgent() {
      if [ -x ${pkgs.beep}/bin/beep ]; then
        ${pkgs.beep}/bin/beep \
          -f 880 -l 100 -r 3 -d 80 \
          -n -f 1047 -l 220 || true
      else
        ${pkgs.util-linux}/bin/setterm -blength 220 -bfreq 1500 >/dev/console 2>/dev/null || true
        printf "\a" >/dev/console; ${pkgs.coreutils}/bin/sleep 0.10
        printf "\a" >/dev/console; ${pkgs.coreutils}/bin/sleep 0.10
        printf "\a" >/dev/console; ${pkgs.coreutils}/bin/sleep 0.10
        printf "\a" >/dev/console
      fi
    }

    # Гарантированно поднять все каналы нужной карты: проходим по всем
    # simple mixer controls (Master, Speaker, Headphone, PCM, …) и
    # выставляем 80% + unmute за один вызов. Игнорируем ошибки отдельных
    # каналов — на разных картах/доках состав разный.
    alsa_ensure_unmuted() {
      if ! [ -x ${pkgs.alsa-utils}/bin/amixer ]; then
        return 0
      fi
      local ctl
      for ctl in $(${pkgs.alsa-utils}/bin/amixer scontrols 2>/dev/null \
                   | sed -n "s/^Simple mixer control '\([^']*\)',.*$/\1/p"); do
        ${pkgs.alsa-utils}/bin/amixer -q set "$ctl" 80% unmute >/dev/null 2>&1 || true
      done
    }

    # ALSA-fallback: один тон нужной частоты, 0.6 сек.
    # Перед проигрыванием принудительно поднимаем все каналы — на многих
    # ноутбуках и в док-станциях канал по умолчанию приглушён, и без
    # unmute speaker-test отыгрывает тишину.
    play_alsa() {
      local freq="$1"
      if [ -x ${pkgs.alsa-utils}/bin/speaker-test ]; then
        alsa_ensure_unmuted
        (${pkgs.alsa-utils}/bin/speaker-test -t sine -f "$freq" -l 1 >/dev/null 2>&1 &) || true
        ${pkgs.coreutils}/bin/sleep 0.6
      fi
    }

    # Пытаемся PC speaker / консольный BEL. Если оба не сработали — ALSA.
    # Простой детектор: пробуем beep, иначе BEL, иначе ALSA.
    use_alsa=0
    if [ ! -x ${pkgs.beep}/bin/beep ] && ! [ -w /dev/console ]; then
      use_alsa=1
    fi

    # Порядок: сначала warning (мягче), потом urgent (настойчивее)
    if [ "$warning_due" -eq 1 ]; then
      if [ "$use_alsa" -eq 1 ]; then play_alsa 784; else play_warning; fi
      ${pkgs.coreutils}/bin/sleep 0.25
    fi
    if [ "$urgent_due" -eq 1 ]; then
      if [ "$use_alsa" -eq 1 ]; then play_alsa 1047; else play_urgent; fi
    fi

    [ "$urgent_due" -eq 1 ] && echo "$now" >"$LAST_URGENT_FILE" 2>/dev/null || true
    [ "$warning_due" -eq 1 ] && echo "$now" >"$LAST_WARNING_FILE" 2>/dev/null || true
  '');

in {
  options.pro.power.lowBattery.beep = {
    enable = mkEnableOption "звуковое оповещение при низком заряде батареи" // { default = true; };

    warningThreshold = mkOption {
      type = types.int;
      default = 30;
      description = "Мягкий сигнал: процент заряда, ниже которого начинается первое предупреждение (восходящий мажор).";
    };

    urgentThreshold = mkOption {
      type = types.int;
      default = 20;
      description = "Настойчивый сигнал: процент заряда, ниже которого играет тревожный паттерн.";
    };

    warningCooldownSec = mkOption {
      type = types.int;
      default = 300;
      description = "Минимальный интервал (сек) между мягкими сигналами.";
    };

    urgentCooldownSec = mkOption {
      type = types.int;
      default = 120;
      description = "Минимальный интервал (сек) между тревожными сигналами.";
    };

    forceTest = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Принудительный тест: при включении всегда отыгрывает оба уровня при срабатывании таймера.
        Для одноразового запуска можно задать PRO_BEEP_FORCE=1 через systemd-run.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.pro-beep-low-battery = {
      description = "Two-level beep on low battery (PC speaker/ALSA fallback)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${script}/bin/pro-beep-low-battery";
        NoNewPrivileges = true;
      };
    };

    systemd.timers.pro-beep-low-battery = {
      description = "Timer: check battery and beep on threshold";
      wantedBy = [ "timers.target" ];
      partOf = [ "pro-beep-low-battery.service" ];
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
