# modules/pro-emacs-rescue.nix — external kill-switch for a stuck EXWM/Emacs.
#
# Why this exists:
#   When Emacs is the window manager (EXWM), a frozen Emacs (infinite
#   package-fetch loop, network stall, GC pause, etc.) blocks every
#   global key, including C-g.  This module provides a recovery path
#   that lives OUTSIDE Emacs:
#
#     1. xbindkeys (a tiny X11 daemon) grabs a dedicated key
#        (default: Control+Alt+Shift+r) BEFORE EXWM starts.
#     2. On press, it runs `pro-emacs-rescue` (this file).
#     3. The script first sends SIGUSR2 to every emacs process.  Emacs
#        handles USR2 in C and enters the recursive debugger at the next
#        eval step, even mid tight loop, so the key always wins.
#     4. If SIGUSR2 is rejected (no process / permissions), the script
#        tries a 2-second emacsclient ping and, if that works, looks
#        for a stuck *Package* / *elpaca* buffer and pokes it.
#     5. Last resort: kill the old scope and relaunch via
#        `systemd-run --user --scope`, the same path exwm-session uses.
#
# Lifecycle:
#   - `pro-emacs-rescue` is shipped as a system package
#     (/run/current-system/sw/bin/pro-emacs-rescue) so the path is
#     stable and is not tied to $HOME.
#   - `xbindkeysrc` is shipped as a share file
#     (/run/current-system/sw/share/pro-emacs-rescue/xbindkeysrc)
#     and points to the absolute path of the rescue binary.
#   - emacs/exwm.nix writes ~/.xprofile that launches `xbindkeys -f`
#     against that absolute path; lightdm's xsession-wrapper sources
#     ~/.xprofile BEFORE EXWM is started, so the grab is in place when
#     Emacs is launched and remains reachable even if Emacs freezes.
#
# Activation:
#   - The package is always installed (cheap; no harm on headless hosts).
#   - The ~/.xprofile deployment is gated by pro.emacs.enable (HM),
#     which is true for all NixOS users in pro-users-nixos.nix.
{ config, lib, pkgs, ... }:

let
  cfg = config.pro.emacs.rescue;

  rescueScript = pkgs.writeShellScript "pro-emacs-rescue" ''
    set -u

    PATH="/run/current-system/sw/bin:/run/wrappers/bin:$PATH"

    LOG_DIR="$HOME/.cache/emacs-startup"
    LOG_FILE="$LOG_DIR/rescue.log"
    mkdir -p "$LOG_DIR"
    log() {
      printf '[pro-emacs-rescue %s] %s\n' "$(date '+%F %T%z')" "$*" >>"$LOG_FILE"
    }

    notify() {
      log "$*"
      if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical -a "pro-emacs-rescue" "Emacs rescue" "$*"
      fi
    }

    EMACSCLIENT="$(command -v emacsclient || true)"
    TIMEOUT="$(command -v timeout || true)"

    # Primary action: SIGUSR2.  Emacs's C handler for USR2 invokes the
    # recursive debugger at the next eval step, even mid tight loop, so
    # the key always wins over a stuck event loop / native code.  In the
    # *Backtrace* buffer the user can hit `q` to abort, `c` to continue,
    # `e` to evaluate, etc.  This is what unblocks a frozen EXWM.
    emacs_pids="$(pidof emacs 2>/dev/null || true)"
    if [ -n "$emacs_pids" ]; then
      sent=0
      for pid in $emacs_pids; do
        if kill -USR2 "$pid" 2>/dev/null; then
          log "sent SIGUSR2 to emacs pid=$pid"
          sent=$((sent + 1))
        fi
      done
      if [ "$sent" -gt 0 ]; then
        notify "Sent SIGUSR2 to emacs (pids: $emacs_pids); recursive debugger should open"
        exit 0
      fi
      log "kill -USR2 failed for all emacs pids; falling through to restart"
    else
      log "no emacs process found; nothing to rescue"
    fi

    # Secondary: ask emacsclient whether a stuck *package* / *elpaca*
    # buffer is the actual cause.  If yes, poke it.  This handles the
    # case where USR2 somehow does not fire but Emacs is still answering
    # emacsclient.  Best-effort only.
    if [ -n "$EMACSCLIENT" ] && [ -n "$TIMEOUT" ] \
       && "$TIMEOUT" 2 "$EMACSCLIENT" -e "(progn (message \"rescue-ping\") t)" >/dev/null 2>&1; then
      stuck="$(
        "$TIMEOUT" 2 "$EMACSCLIENT" -e \
          '(condition-case nil
             (let ((re "\\\\*[a-z]*-\\(package\\|elpaca\\)\\(\\|<[0-9]+>\\)"))
               (seq-some
                (lambda (b)
                  (and (string-match-p re (buffer-name b))
                       (buffer-name b)))
                (buffer-list)))
             (error nil))' 2>/dev/null
      )"
      stuck="$(printf '%s' "$stuck" | tr -d '"' | tr -d '\n')"
      if [ -n "$stuck" ]; then
        notify "Emacs stuck on $stuck; sending RET to that buffer"
        "$TIMEOUT" 3 "$EMACSCLIENT" -e \
          "(with-current-buffer \"$stuck\" (goto-char (point-max)) (insert \"\\n\") (sit-for 0.1))" \
          >/dev/null 2>&1 || true
      else
        notify "Emacs answered emacsclient but USR2 failed; check manually"
      fi
      exit 0
    fi

    # Last resort: emacs is wedged beyond USR2 recovery (e.g. stuck in
    # kernel I/O or native code without USR2 handler).  Restart it the
    # same way emacs/exwm.nix:exwm-session does.
    notify "Emacs unresponsive to USR2 and emacsclient; restarting via systemd-run"
    systemctl --user stop "emacs*.scope" 2>/dev/null || true
    pkill -TERM -x emacs 2>/dev/null || true
    sleep 1
    pkill -KILL -x emacs 2>/dev/null || true
    sleep 1

    setsid /run/current-system/sw/bin/systemd-run --user --scope \
      -E XDG_CURRENT_DESKTOP=EXWM \
      -E DISPLAY \
      -E XAUTHORITY \
      -E DBUS_SESSION_BUS_ADDRESS \
      -E PATH \
      -E HOME \
      -E USER \
      -- /run/current-system/sw/bin/emacs --init-directory "$HOME/.config/emacs" \
      </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null || true
    log "restart dispatched; pid_candidate=$!"
    exit 0
  '';

  rescuePkg = pkgs.runCommand "pro-emacs-rescue-pkg" { } ''
    mkdir -p $out/bin $out/share/pro-emacs-rescue
    cp ${rescueScript} $out/bin/pro-emacs-rescue
    chmod +x $out/bin/pro-emacs-rescue
    cat > $out/share/pro-emacs-rescue/xbindkeysrc <<EOF
    # xbindkeys config for pro-emacs-rescue.
    # Loaded by emacs/exwm.nix via `xbindkeys -f` against an absolute path.
    # The key is grabbed BEFORE EXWM starts (xbindkeys is started from
    # ~/.xprofile which lightdm sources before exec'ing the window manager),
    # so it remains reachable even when Emacs is frozen.
    "$out/bin/pro-emacs-rescue"
        ${cfg.key}
    EOF
  '';

  xbindkeysAbsPath = "${rescuePkg}/share/pro-emacs-rescue/xbindkeysrc";
in
{
  options.pro.emacs.rescue = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "external kill-switch for a stuck EXWM/Emacs (xbindkeys + pro-emacs-rescue)";
    };

    # xbindkeys "keystring" syntax (case-insensitive modifiers).
    # Defaults to a combo present on every laptop keyboard and unlikely
    # to be grabbed by EXWM (which only consumes s-<letter>).
    key = lib.mkOption {
      type = lib.types.str;
      default = "Control+Alt+Shift+r";
      example = "Mod4 + Scroll_Lock";
      description = ''
        Key combination that triggers pro-emacs-rescue.
        Written verbatim into the generated xbindkeysrc, so any
        xbindkeys keystring is accepted.  Keep it memorable and avoid
        anything EXWM already grabs.
      '';
    };
  };

  # The package (and xbindkeys) is always available.  Cheap; useful even on
  # headless hosts for ad-hoc invocation.  Per AGENTS §2: plain assignment.
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ rescuePkg pkgs.xbindkeys ];
    environment.etc."pro/emacs-rescue/xbindkeysrc".source = xbindkeysAbsPath;
  };
}
