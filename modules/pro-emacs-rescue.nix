# modules/pro-emacs-rescue.nix — external kill-switch for a stuck EXWM/Emacs.
#
# Why this exists:
#   When Emacs is the window manager (EXWM), a frozen Emacs (infinite
#   package-fetch loop, network stall, GC pause, etc.) blocks every
#   global key, including C-g.  This module provides a recovery path
#   that lives OUTSIDE Emacs:
#
#     1. xbindkeys (a tiny X11 daemon) grabs a dedicated key
#        (Super+Scroll_Lock) BEFORE EXWM starts.
#     2. On press, it runs `pro-emacs-rescue` (this file).
#     3. The script first tries a 2-second emacsclient ping.
#     4. If Emacs responds, it inspects the buffer list for stuck
#        *Package* / *elpaca* / similar loaders and pokes them.
#     5. If Emacs is unreachable, the script restarts it via the same
#        `systemd-run --user --scope` mechanism that exwm-session uses.
#
# Lifecycle:
#   - `pro-emacs-rescue` is shipped as a system package
#     (/run/current-system/sw/bin/pro-emacs-rescue) so the path is
#     stable and is not tied to $HOME.
#   - `xbindkeysrc` is shipped as a share file
#     (/run/current-system/sw/share/pro-emacs-rescue/xbindkeysrc)
#     and points to the absolute path of the rescue binary.
#   - emacs/exwm.nix launches `xbindkeys -f` against that absolute
#     path in exwm-session, so the key grab happens BEFORE EXWM.
#
# Activation:
#   - The package is always installed (cheap; no harm on headless hosts).
#   - The xbindkeys launch in exwm-session is gated by
#     pro.emacs.gui.enable (only the EXWM host needs the grab).
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

    # 1) Soft probe: can Emacs answer at all?
    if [ -n "$EMACSCLIENT" ] && [ -n "$TIMEOUT" ] \
       && "$TIMEOUT" 2 "$EMACSCLIENT" -e "(progn (message \"rescue-ping\") t)" >/dev/null 2>&1; then
      # Emacs is alive.  Look for a stuck *package* / *elpaca* buffer.
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
        notify "Emacs responsive; nothing to do"
      fi
      exit 0
    fi

    # 2) Hard plan: kill the old scope + process, then relaunch in the same way
    #    emacs/exwm.nix:exwm-session does.  systemd-run --user --scope creates
    #    a transient unit whose name matches "emacs*.scope"; we stop it best-effort.
    notify "Emacs unresponsive; restarting via systemd-run"
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
    # The key is grabbed BEFORE EXWM starts (xbindkeys is started at the top
    # of exwm-session), so it remains reachable even when Emacs is frozen.
    "$out/bin/pro-emacs-rescue"
        Mod4 + Scroll_Lock
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
  };

  # The package (and xbindkeys) is always available.  Cheap; useful even on
  # headless hosts for ad-hoc invocation.  Per AGENTS §2: plain assignment.
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ rescuePkg pkgs.xbindkeys ];
    environment.etc."pro/emacs-rescue/xbindkeysrc".source = xbindkeysAbsPath;
  };
}
