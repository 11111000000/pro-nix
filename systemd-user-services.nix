# Файл: автосгенерированная шапка — комментарии рефакторятся
{ pkgs, emacsPkg }:

let
  # Отдельный интерпретатор Python, в котором гарантированно есть `requests`,
  # чтобы org-babel не зависел от того, какой `python` попал в PATH (например, из ~/.nix-profile).
  pyWithRequests = pkgs.python3.withPackages (ps: [ ps.requests ]);
  pyForBabel = "${pyWithRequests}/bin/python3";
in
{
  "nm-applet" = {
    Unit = {
      Description = "NetworkManager Applet";
      After = [ "exwm-session.target" "dbus.service" ];
      Wants = [ "dbus.service" ];
      PartOf = [ "exwm-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.networkmanagerapplet}/bin/nm-applet";
      Restart = "on-failure";
    };
    Install = { WantedBy = [ "exwm-session.target" ]; };
  };

  "blueman-applet" = {
    Unit = {
      Description = "Blueman Applet";
      After = [ "exwm-session.target" "dbus.service" ];
      Wants = [ "dbus.service" ];
      PartOf = [ "exwm-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.blueman}/bin/blueman-applet";
      Restart = "on-failure";
    };
    Install = { WantedBy = [ "exwm-session.target" ]; };
  };

  "copyq" = {
    Unit = {
      Description = "CopyQ Clipboard Manager";
      After = [ "exwm-session.target" "dbus.service" ];
      Wants = [ "dbus.service" ];
      PartOf = [ "exwm-session.target" ];
    };
    Service = {
      Environment = [
        "QT_QPA_PLATFORM=xcb"
      ];
      ExecStart = "${pkgs.copyq}/bin/copyq";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install = { WantedBy = [ "exwm-session.target" ]; };
  };

  "udiskie-tray" = {
    Unit = {
      Description = "Udiskie tray automounter";
      After = [ "exwm-session.target" "dbus.service" ];
      Wants = [ "dbus.service" ];
      PartOf = [ "exwm-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.udiskie}/bin/udiskie -t";
      Restart = "on-failure";
    };
    Install = { WantedBy = [ "exwm-session.target" ]; };
  };

  "dunst" = {
    Unit = {
      Description = "Dunst Notifications Daemon";
      After = [ "exwm-session.target" "dbus.service" ];
      Wants = [ "dbus.service" ];
      PartOf = [ "exwm-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.dunst}/bin/dunst -conf %h/.config/dunst/dunstrc";
      Restart = "on-failure";
    };
    Install = { WantedBy = [ "exwm-session.target" ]; };
  };

  "pasystray" = {
    Unit = {
      Description = "PulseAudio/PipeWire Tray";
      After = [ "exwm-session.target" "dbus.service" ];
      Wants = [ "dbus.service" ];
      PartOf = [ "exwm-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.pasystray}/bin/pasystray";
      Restart = "on-failure";
    };
    Install = { WantedBy = [ "exwm-session.target" ]; };
  };

  "snixembed" = {
    Unit = {
      Description = "Bridge StatusNotifier (SNI) icons to XEmbed for EXWM tray";
      After = [ "exwm-session.target" "dbus.service" ];
      Wants = [ "dbus.service" ];
      PartOf = [ "exwm-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.snixembed}/bin/snixembed";
      Restart = "on-failure";
    };
    Install = { WantedBy = [ "exwm-session.target" ]; };
  };

  # "evremap" = {
  #   Unit = {
  #     Description = "evremap (user) - Emacs-like keys in browsers";
  #     After = [ "exwm-session.target" "dbus.service" ];
  #     Wants = [ "dbus.service" ];
  #     PartOf = [ "exwm-session.target" ];
  #   };
  #   Service = {
  #     ExecStart = "${pkgs.evremap}/bin/evremap remap %h/.config/nixos/conf/evremap.toml";
  #     Restart = "on-failure";
  #     RestartSec = 2;
  #   };
  #   Install = { WantedBy = [ "exwm-session.target" ]; };
  # };

  "xset-dpms-off" = {
    Unit = {
      Description = "Disable screen blanking and DPMS with xset";
      After = [ "exwm-session.target" ];
      PartOf = [ "exwm-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -lc '${pkgs.xorg.xset}/bin/xset s noblank; ${pkgs.xorg.xset}/bin/xset s off; ${pkgs.xorg.xset}/bin/xset -dpms'";
    };
    Install = { WantedBy = [ "exwm-session.target" ]; };
  };

  "polkit-gnome-authentication-agent-1" = {
    Unit = {
      Description = "polkit-gnome authentication agent";
      After = [ "exwm-session.target" "dbus.service" ];
      Wants = [ "dbus.service" ];
      PartOf = [ "exwm-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
    Install = { WantedBy = [ "exwm-session.target" ]; };
  };

  "ollama" = {
    Unit = {
      Description = "Ollama Local LLM Server";
      After = [ "exwm-session.target" ];
      PartOf = [ "exwm-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.ollama}/bin/ollama serve";
      Environment = [
        "OLLAMA_HOST=127.0.0.1:11434"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = { WantedBy = [ "exwm-session.target" ]; };
  };

}
