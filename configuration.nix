# configuration.nix: Конфигурация системы NixOS
# 
# Данный файл задаёт полное описание системы NixOS, оформленное в стиле "литературного программирования" 
# Каждая секция предваряется пояснением, раскрывающим её смысл, назначение и взаимосвязи с другими частями системы.
#
# Структура конфигурации выстроена иерархически:
# — Базовые импорты и модули.
# — Ключевые системные параметры (загрузчик, ядро, сеть).
# — Аппаратная поддержка и базовые сервисы (ввод, Bluetooth, энергосбережение).
# — Локализация и языковые стандарты.
# — Графическая среда и оконные менеджеры (X11, KDE, EXWM).
# — Обслуживающие службы (печать, звук, виртуализация, прокси).
# — Пользовательские настройки и Home Manager.
# — Системные пакеты и среда.
# — Особые приёмы (переназначение клавиш, монтирование, пользовательские сервисы).
#
# Каждый блок начинается с подробного пояснения, далее приводится соответствующий Nix-код с подробными комментариями.
# Это обеспечивает связность структуры и способствует долгосрочному сопровождению системы.
#
# Пример ориентирован на ноутбук с процессором Intel, NVMe-диском и модулем Bluetooth — при необходимости скорректируйте под своё оборудование.

{ config, pkgs, lib, ... }:

let
  local = if builtins.pathExists ./local.nix then import ./local.nix else { };
  hostName = local.hostName or "nixos";
  emacsPkg = pkgs.emacs30 or pkgs.emacs;
  home-manager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/refs/heads/release-25.11.tar.gz";
    sha256 = "16mcnqpcgl3s2frq9if6vb8rpnfkmfxkz5kkkjwlf769wsqqg3i9";
  };
in

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 1: Импортируемые модули и включение дополнительной логики
#
# На начальном этапе загружаются необходимые модули: результаты автоматического 
# сканирования железа, Home Manager для персональных настроек, а также при необходимости 
# нестабильные или пользовательские модули (например, для более гибкой работы с клавишами).

{
  imports = [
    # Импортируется конфиг, сгенерированный скриптом аппаратного сканирования NixOS.
    ./hardware-configuration.nix

    # Общие смысловые модули.
    ./modules/pro-users.nix
    ./modules/nix-cuda-compat.nix

    # Локальные переопределения конкретного хоста.
  ] ++ lib.optionals (builtins.pathExists ./local.nix) [ ./local.nix ] ++ [

    # Модуль Home Manager для управления пользовательскими параметрами.
    (import "${home-manager}/nixos")

    # Вспомогательный модуль для переназначения клавиш (xremap) подключён по требованию.
    # <nixos-unstable/nixos/modules/services/misc/xremap.nix>
  ];


# ──────────────────────────────────────────────────────────────────────────────
# Раздел 2: Загрузчик системы и параметры ядра
#
# Здесь настраивается механизм загрузки для систем с EFI, ограничивается число хранемых
# конфигураций для экономии места, а также выбирается самое современное ядро для максимальной
# безопасности и совместимости с новым железом.

  boot.loader.systemd-boot.enable = true;             # Использовать systemd-boot для EFI.
  boot.loader.efi.canTouchEfiVariables = true;        # Разрешить запись в EFI-память.
  boot.loader.efi.efiSysMountPoint = "/boot";         # Явно указываем точку монтирования ESP.
  boot.loader.systemd-boot.configurationLimit = 6;    # Уменьшаем число поколений для экономии места на ESP.
  boot.loader.timeout = 5;                            # Показывать меню загрузчика 5 секунд.
  boot.loader.systemd-boot.editor = true;             # Разрешить редактирование параметров загрузки (например, systemd.unit=multi-user.target).

  boot.plymouth.enable = true;                        # Boot splash - nicer boot experience.
  boot.plymouth.theme = "spinner";                     # Simple spinner theme - reliable and clean.

  boot.kernelPackages = pkgs.linuxPackages_6_6;        # LTS ядро: стабильнее suspend/resume на Tiger Lake.
  boot.kernelParams = [ "mem_sleep_default=s2idle" "i915.enable_psr=0" "nvme_core.default_ps_max_latency_us=0" "acpi_backlight=native" ];
  boot.kernel.sysctl."kernel.sysrq" = 1;               # Magic SysRq: вернуть управление и переключиться на TTY (Alt+SysRq+R и др.).
  boot.resumeDevice = "/dev/nvme0n1p3";                 # Устройство swap для корректного resume из гибернации (уточните при необходимости)

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 3: Сетевая конфигурация и имя машины
#
# В этом разделе задаётся уникальное имя компьютера и выбирается менеджер сетевых
# подключений для гибкой работы в различных сетевых окружениях. Wi-Fi управляется 
# через NetworkManager (ручная настройка отключена).

  networking.hostName = hostName;  # Имя хоста задаётся локальным, gitignored конфигом.

  # Не используем "старую" систему беспроводной связи — вместо этого мы делегируем
  # управление беспроводными сетями NetworkManager.
  # networking.wireless.enable = true;

  networking.networkmanager.enable = true; # Активируем NetworkManager для управления сетью.
  services.samba.enable = true;
  services.samba.openFirewall = true;
  services.avahi.enable = true;
  services.avahi.publish.enable = true;
  services.samba.settings = {
    global = {
      workgroup = "WORKGROUP";
      "server string" = "NixOS Samba Server";
      "map to guest" = "Bad User";
      "usershare allow guests" = "Yes";
    };

    ${hostName} = {
      path = "/srv/samba/${hostName}";
      browseable = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "force group" = "pro";
      "create mask" = "0775";
      "directory mask" = "2775";
      "valid users" = "az zoya lada boris";
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/samba/${hostName} 2775 root pro - -"
  ];

  # Используем systemd-resolved и задаём собственные DNS-серверы (Яндекс + fallback)
  networking.nameservers = [ "77.88.8.8" "77.88.8.1" "1.1.1.1" "8.8.8.8" ];   # Приоритет — Яндекс, после fallback.
  networking.networkmanager.dns = "systemd-resolved"; # NM отдаёт резолвинг systemd-resolved.

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 4: Часовой пояс и языковая локализация
#
# Определяются базовые параметры часового пояса и языковые стандарты для корректного 
# отображения времени, валют, адресов и других региональных настроек. Основной язык — русский.

  time.timeZone = "Asia/Irkutsk";           # Географический регион для времени и даты.

  # Основная локаль системы (русский Unicode).
  i18n.defaultLocale = "ru_RU.UTF-8";

  # Расширенные языковые параметры для согласованной работы приложений.
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };
  security.sudo.wheelNeedsPassword = false;

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 5: Аппаратная поддержка и базовые сервисы
#
# Здесь обеспечивается поддержка ввода (мыши, тачпады), Bluetooth, энергосбережения, 
# а также автоматическое обновление микрокода процессоров Intel. Настроены параметры 
# управления электропитанием, очистки временных файлов, и актуализация прошивок для оборудования.

  services.libinput = {
    enable = true;                      # Универсальный драйвер для всех устройств ввода.
    touchpad.disableWhileTyping = true;  # Блокировать случайные нажатия тачпада во время печати.
  };

  hardware.bluetooth.enable = true;         # Включаем поддержку Bluetooth.
  hardware.bluetooth.settings = {
    General = { AutoEnable = true; };       # Адаптер включается автоматически.
  };
  services.blueman.enable = true;           # Графический интерфейс управления Bluetooth.

  powerManagement.enable = true;           # Общесистемное управление питанием.
    powerManagement.resumeCommands = ''
    modprobe -r battery ac 2>/dev/null || modprobe -r battery
    sleep 1
    modprobe battery
    modprobe ac 2>/dev/null || true
    udevadm trigger -s power_supply || true
    udevadm settle -t 5 || true
    ${pkgs.upower}/bin/upower --enumerate >/dev/null 2>&1 || true
    systemctl try-restart upower.service 2>/dev/null || true

    for n in XHCI RP05; do
      if awk -v d="$n" '$1==d && $3 ~ /\*enabled/' /proc/acpi/wakeup >/dev/null 2>&1; then
        echo "$n" > /proc/acpi/wakeup || true
      fi
    done
  '';
  
  # Параметры сна/гибернации.
  services.logind = {
    settings.Login = {
      LidSwitchIgnoreInhibited = "no";
      HandlePowerKey = "suspend-then-hibernate";
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "suspend";
    };
  };

  services.upower = {
    enable = true;
    usePercentageForPolicy = true;
    percentageLow = 15;
    percentageCritical = 10;
    percentageAction = 8;
    criticalPowerAction = "Hibernate";
  };
  services.power-profiles-daemon.enable = true;    # Современный демон профилей питания.

  hardware.enableAllFirmware = true;        # Всегда иметь под рукой последние прошивки для Wi-Fi, Bluetooth и проч.

  # Добавляем прошивку Intel SOF для Tiger Lake (исправляет "SOF firmware ... not found" и отсутствие /dev/snd/pcm*):
  hardware.firmware = [ pkgs.sof-firmware ];

  hardware.cpu.intel.updateMicrocode = true; # Микрокод Intel — критично для безопасности.
  hardware.uinput.enable = true;            # Для evremап: предоставляет /dev/uinput и группу uinput.
  boot.extraModprobeConfig = ''
    options snd-intel-dspcfg dsp_driver=1
  '';

  services.xserver.videoDrivers = [ "modesetting" ];   # Драйвер видео: для большинства Intel Xe рекомендуется modesetting.
  # Используем swap-файл на диске для поддержки гибридного сна и гибернации.
  swapDevices = [
    { device = "/dev/nvme0n1p3"; }
  ];

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 6: Особенности Nix и расширенные возможности
#
# Включены дополнительные механизмы для поддержки AppImage, динамических бинарников, 
# а также активация экспериментальных функций системы сборки Nix (flakes). 

  programs.nix-ld.enable = true;  

  # Включение flakes, регулярная очистка и оптимизация кэша пакетов.
  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
    settings.connect-timeout = 5;
    settings.fallback = true;
    # Cachix first: prefer the faster community cache before falling back to the public one.
    settings.substituters = lib.mkForce [
      "https://nix-community.cachix.org?priority=1"
      "https://cache.nixos.org?priority=50"
    ];
    settings.trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    settings.trusted-substituters = [
      "https://nix-community.cachix.org"
      "https://nix-mirror.freetls.fastly.net"
    ];
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    optimise.automatic = true;
  };

  # Позволяем использовать не полностью открытые пакеты.
  nixpkgs.config = {
    allowUnfree = true;
  };

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 7: Графическая среда и оконные менеджеры
#
# Активируется X11 и две графические среды: KDE Plasma (полноценный DE) и EXWM (Emacs в роли WM).
# Устанавливаются правила автоматического входа и поведения системы при закрытии крышки и нажатии кнопки питания.

  services.xserver.enable = true;                  # Включение X-сервера.

  services.xserver.displayManager.gdm.enable = true;      # GDM включен как основной DM.
  services.xserver.desktopManager.cinnamon.enable = true;

  services.xserver.displayManager.sessionCommands = ''
    export PATH="/run/wrappers/bin:$HOME/.opencode/bin:$HOME/.local/bin:/run/current-system/sw/bin:$PATH"
    export EMACS_STARTUP_LOG_DIR="$HOME/.cache/emacs-startup"
    export EMACS_STARTUP_LOG_FILE="$EMACS_STARTUP_LOG_DIR/gdm-exwm.log"
    mkdir -p "$EMACS_STARTUP_LOG_DIR"
    printf '%s\n' "[sessionCommands $(date '+%F %T%z')] path=$PATH log_file=$EMACS_STARTUP_LOG_FILE"
    [ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" || true
  '';

  services.xserver.displayManager.autoLogin.enable = false;

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 8: Масштабная настройка клавиатуры и ввода

  console.useXkbConfig = true;                # Консоль унаследует X11-раскладку и опции.
  console.earlySetup = true;                  # Установка шрифта на ранней стадии загрузки (в initrd).
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";  # Terminus - sharper Cyrillic font.

  services.xserver.xkb = {
    layout = "us,ru";
    options = "grp:toggle,caps:ctrl_modifier,grp_led:caps"; # Right Alt toggles EN/RU in Xorg and TTY.
  };

  systemd.services.kbdrate = {
    description = "Задание интервалов повторения на виртуальной консоли";
    wantedBy = [ "multi-user.target" ];
    after = [ "getty@tty1.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kbd}/bin/kbdrate -d 900 -r 7";
    };
  };

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 9: Службы печати и звука

  services.pulseaudio.enable = false;              # Явно отключаем PulseAudio (используем PipeWire)
  security.rtkit.enable = true;                # Для PipeWire — снижение задержек в реальном времени.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 10: Пользователи и Home Manager

  users.users = builtins.listToAttrs (map (name: {
    inherit name;
    value = {
      isNormalUser = true;
      description = name;
      extraGroups = [ "networkmanager" "wheel" "bluetooth" "docker" "input" "uinput" ];
      packages = [ ];
      openssh.authorizedKeys.keys = [ ];
    };
  }) [ "az" "zoya" "lada" "boris" ]);

  users.groups.pro = { };

  security.sudo.extraRules = [
    {
      users = [ "az" "zoya" "lada" "boris" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];

  home-manager = {
    extraSpecialArgs = { inherit pkgs; };
    backupFileExtension = "backup";
    users = builtins.listToAttrs (map (name: {
      inherit name;
      value = { config, lib, pkgs, ... }: {
        home.username = name;
        home.homeDirectory = "/home/${name}";
        home.stateVersion = "23.11";
        home.enableNixpkgsReleaseCheck = false;
        home.sessionPath = [
          "/home/${name}/.opencode/bin"
          "/home/${name}/.local/bin"
        ];
        home.sessionVariables = {
          QUOTING_STYLE = "literal";
          LANG = "ru_RU.UTF-8";
        };
        home.packages = with pkgs; [
          fd
          ripgrep
          xclip
          rxvt-unicode
          poppler-utils
          home-manager
          obexd
          fnm
        ];
        home.file.".config/gtk-3.0/settings.ini".source = ./conf/gtk-3.0-settings.ini;
        home.file.".config/gtk-4.0/settings.ini".source = ./conf/gtk-4.0-settings.ini;
        home.file.".gtkrc-2.0".source = ./conf/gtkrc-2.0;
        home.file.".Xresources".source = ./conf/Xresources;
        home.file.".xprofile".text = ''
          [ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" || true
          [ -x "$HOME/.local/bin/emacs-panic" ] && pgrep -x xbindkeys >/dev/null 2>&1 || xbindkeys
        '';
        home.file.".config/qt5ct/qt5ct.conf".source = ./conf/qt5ct.conf;
        home.file.".config/qt6ct/qt6ct.conf".source = ./conf/qt6ct.conf;
        home.file.".config/dunst/dunstrc".source = ./conf/dunstrc;
        home.file.".config/fontconfig/fonts.conf".source = ./conf/fonts.conf;
        home.file.".tridactylrc".source = ./conf/tridactylrc;
        home.file.".local/share/applications/firefox.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Firefox
          Exec=/run/current-system/sw/bin/firefox %u
          Terminal=false
          Categories=Network;WebBrowser;
          StartupNotify=true
          MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
        '';
        home.file.".local/share/applications/chromium.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Chromium
          Exec=/run/current-system/sw/bin/chromium %u
          Terminal=false
          Categories=Network;WebBrowser;
          StartupNotify=true
          MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
        '';
        home.file.".local/share/applications/google-chrome.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Google Chrome
          Exec=/run/current-system/sw/bin/google-chrome %u
          Terminal=false
          Categories=Network;WebBrowser;
          StartupNotify=true
          MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
        '';
        home.file.".local/share/applications/pro-emacs.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Pro Emacs
          Exec=/run/current-system/sw/bin/pro-emacs-session
          Terminal=false
          Categories=Development;Utility;
          StartupNotify=true
        '';
        home.file.".config/autostart/systemd-user-import-env.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Import systemd --user env
          Exec=/run/current-system/sw/bin/sh -lc 'systemctl --user import-environment DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS'
          X-GNOME-Autostart-enabled=true
        '';
        home.file.".local/bin/gnome-gtk-session-env-fix.sh" = {
          text = ''
            #!/usr/bin/env sh
            set -eu
            systemctl --user import-environment DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP
            systemctl --user stop gnome-terminal-server.service 2>/dev/null || true
            pkill -f '^nemo( |$)' 2>/dev/null || true
            gsettings set org.cinnamon.desktop.screensaver lock-enabled false 2>/dev/null || true
          '';
          executable = true;
        };
        home.file.".config/autostart/session-env-fix.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Session env fix
          Exec=/run/current-system/sw/bin/sh -lc "$HOME/.local/bin/gnome-gtk-session-env-fix.sh"
          X-GNOME-Autostart-enabled=true
          OnlyShowIn=X-Cinnamon;
        '';
        home.file.".emacs.d/early-init.el".source = ./emacs/base/early-init.el;
        home.file.".emacs.d/init.el".source = ./emacs/base/init.el;
        home.file.".emacs.d/site-init.el".source = ./emacs/base/site-init.el;
        home.file.".emacs.d/modules.el.example".text = ''
          ;; Copy to ~/.emacs.d/modules.el and edit the list.
          ;; User modules win; the system base is a fallback.
          (setq pro-emacs-modules '(core ui git nix js ai exwm))
        '';
        home.activation.tridactyl-reminder = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          echo "[Tridactyl] Проверьте, что расширение Tridactyl установлено в Firefox (https://tridactyl.xyz)."
        '';
        programs.home-manager.enable = true;
      };
    }) [ "az" "zoya" "lada" "boris" ]);
  };

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 11: Системные пакеты
  environment.systemPackages = (import ./system-packages.nix { inherit pkgs emacsPkg; });

# ──────────────────────────────────────────────────────────────────────────────
# Раздел 12: Дополнительные службы
  services.udisks2.enable = true;
  services.guix.enable = true;
  services.flatpak.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-gtk ];
  };

  fonts.packages = with pkgs; [
    terminus_font
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    (stdenv.mkDerivation rec {
      name = "aporetic-fonts";
      src = ./fonts;
      installPhase = ''
        mkdir -p $out/share/fonts/truetype
        cp $src/*.ttf $out/share/fonts/truetype/
      '';
    })
    liberation_ttf
    dejavu_fonts
    cantarell-fonts
  ];

  fonts.fontconfig.defaultFonts.monospace = [ "Terminus" "Aporetic Sans Mono" ];

  virtualisation.docker.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin        = "no";
      PasswordAuthentication = true;
      AllowUsers             = [ "zoya" ];
    };
    extraConfig = ''
      Match User zoya
        ChrootDirectory /srv/sftp
        ForceCommand internal-sftp
        X11Forwarding no
        AllowTcpForwarding no
    '';
  };

  services.tor = {
    enable = true;
    client.enable = true;
    torsocks.enable = true;
    settings = {
      SOCKSPort = [ 9052 ];
      ControlPort = [ 9051 ];
      CookieAuthentication = true;
      UseBridges = 1;
      ClientTransportPlugin = lib.mkForce [ "obfs4 exec ${pkgs.obfs4}/bin/lyrebird" ];
      Bridge = [
        "obfs4 157.131.86.3:4151 F09798E5258569811C71BFA98F43975E768CD8B8 cert=gRkZGmnzzzCwnSUT65285BkI1a8ni7R+7tXAYizYUzrlSklcX4rOtl7gU/9unBwblOQ3Ew iat-mode=0"
      ];
      DNSPort = [ 9053 ];
      AutomapHostsOnResolve = true;
      AutomapHostsSuffixes = [ ".onion" ".exit" ];
    };
  };

  services.i2p.enable = true;
  services.resolved.enable = true;

  services.syncthing = {
    enable            = true;
    user              = "zoya";
    group             = "users";
    dataDir           = "/home/zoya/Sync";
    configDir         = "/home/zoya/.config/syncthing";
    guiAddress        = "127.0.0.1:8384";
    openDefaultPorts  = false;
  };

  security.audit.enable = false;
  security.auditd.enable = false;

  services.fail2ban = {
    enable    = true;
    bantime   = "1h";
    maxretry  = 6;
  };

  security.apparmor.enable = true;
  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableSystemSlice = true;
    enableUserSlices = true;
    settings.OOM = {
      DefaultMemoryPressureDurationSec = "10s";
    };
  };
  
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 22000 80 443 9050 9051 9053 7657 4444 4445 8384 139 445 ];
    allowedUDPPorts = [ 21027 53 9564 137 138 ];
    trustedInterfaces = [ "docker0" ];
  };

  environment.variables = {
    LANG = "ru_RU.UTF-8";
    LC_CTYPE = "ru_RU.UTF-8";
    GTK_KEY_THEME = "Emacs";
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt5ct";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
  };

  system.stateVersion = "25.05";

  programs.firefox.enable = true;
  programs.firefox.package = pkgs.firefox;

  powerManagement.powerUpCommands = ''
    for n in XHCI RP05; do
      if awk -v d="$n" '$1==d && $3 ~ /\*enabled/' /proc/acpi/wakeup >/dev/null 2>&1; then
        echo "$n" > /proc/acpi/wakeup || true
      fi
    done
  '';
}
